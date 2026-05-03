# El Metal: Feature-by-Feature Hex-to-Port Migration Analysis

This analysis assumes replacing `claude_code` hex package with hand-rolled `El.ClaudePort` (already started on wip).

## Current Integration Points

**In scope:**
- `lib/el/session.ex:15` — defaults to `El.ClaudeCode` wrapper
- `lib/el/claude_code.ex` — wraps hex pkg `ClaudeCode.Session.start_link/stream`
- `lib/el/session/claude.ex` — pattern matches on `ClaudeCode.Message` structs

**Out of scope (READ ONLY):**
- `~/dev/ext/claude-code/` — never modified, only reverse-engineered for seams

**El.ClaudePort baseline (from wip):**
- Spawns `claude` CLI with stream-json in/out
- Holds persistent Port, calls `ask` returning `{result, model, session_id}`
- GenServer interface matches `El.ClaudeCode` surface (start_link/1, ask/2 via stream)

---

## 1. agent.feature

**What it tests:** Explicit agent flag (`-a kent`), implicit agent detection from name, model override, multi-agent support (kent/lisa).

**Flow:** `El` → `Session.start_link` → `Claude.start` → `claude_module.start_link` → message streams in → `Session.Claude.ask` → pattern match on model in Init message.

**Hex-pkg behavior required:**
- Model inference from agent name (kent → opus, lisa → sonnet, etc.)
- ClaudeCode.Message.SystemMessage.Init struct with `model:` field
- Agent routing in ClaudeCode.Session (settings, profile lookup)

**What breaks with ClaudePort:**
- `El.ClaudePort.ask` returns `{result, model, session_id}` — model is extracted from Init. **CRITICAL**: ClaudePort must parse Init message to extract model, or model defaults to nil and card/info lose model label.
- Agent-to-model mapping bypassed; ClaudePort gets agent in opts but doesn't use it (that's ClaudeCode's job). **Must flow through claude CLI flags** (`claude -c` with agent config? Unclear).
- Setting sources (`["user", "project", "local"]`) — no longer passed to hex pkg. Unclear if ClaudePort needs them.

**Risk:** HARD

**What to verify:** ClaudePort extracts and returns model from Init message; agent detection still works end-to-end (CLI respects agent flag or name heuristic).

---

## 2. card.feature

**What it tests:** Agent card display (name, id, agent label, model label, msg count, last prompt/response).

**Flow:** `el <name>` (no message) → `CallHandler.handle(:info)` → `build_info` reads `state.session_id`, `state.messages`, and extracts model from last message metadata.

**Hex-pkg behavior required:**
- `ClaudeCode.Message.SystemMessage.Init.model` in first event stream
- Metadata persisted in `{type, prompt, response, metadata}` tuple where `metadata[:model]` is set

**What breaks with ClaudePort:**
- Init parse already required (agent.feature). Model must be captured during first ask.
- Card display reads `metadata[:model]` from stored messages. **MUST**: ClaudePort.ask returns model so Ask.finalize_ask can stamp it into metadata.
- Already depends on; No new hex surface.

**Risk:** MODERATE (model extraction already required; message metadata already piped)

**What to verify:** Model appears in card after first message.

---

## 3. clear.feature

**What it tests:** Clear session history, show cleared prompt in parens.

**Flow:** `CallHandler.handle(:clear)` → `Claude.stop_claude` (kill process) → `Ask.reset_session` → new claude_pid + new session_id.

**Hex-pkg behavior required:**
- Process can be stopped cleanly with `GenServer.stop/1`
- Can respawn with new session_id (opt-in, not auto-resume)

**What breaks with ClaudePort:**
- `GenServer.stop(pid)` must work on Port GenServer. **Already safe**: ClaudePort is a GenServer, :stop is standard.
- New session_id on reset. **Check**: Does ClaudePort honor new session_id in opts? (Likely yes, passed to Port init.)

**Risk:** TRIVIAL

**What to verify:** Clear kills old Port, new Port starts fresh, session_id increments.

---

## 4. el2el.feature

**What it tests:** Tell/ask routing between sessions (currently commented out).

**Flow:** `Router.detect_routes` (parse `@name` prefix) → `Router.process_ask_tell` (relay message) → no direct Claude interaction.

**Hex-pkg behavior required:** None directly (inter-session relay is El's job).

**What breaks with ClaudePort:** Nothing. This feature is orthogonal to Claude wrapper.

**Risk:** TRIVIAL

**What to verify:** Routes still work (independent of Claude backend).

---

## 5. exit.feature

**What it tests:** Exit single session, check it leaves registry in "stopped" state.

**Flow:** `CallHandler.handle(:exit)` or Session terminate → `Terminator.handle` → clean up claude_pid, deregister.

**Hex-pkg behavior required:** Process can be killed; hex pkg leaves no dangling refs.

**What breaks with ClaudePort:** Port cleanup. **Check**: Does Port close cleanly on GenServer.stop/1? (Yes, handle_info for exit_status.)

**Risk:** TRIVIAL

**What to verify:** Exit cleans up Port without orphaning processes.

---

## 6. glob.feature

**What it tests:** Pattern matching on session names (donn* matches donny + donner), bulk clear/log/exit.

**Flow:** CLI glob expansion → multiple Session calls (independent). No Claude interaction beyond normal ask/tell.

**Hex-pkg behavior required:** None.

**What breaks with ClaudePort:** Nothing.

**Risk:** TRIVIAL

**What to verify:** Glob patterns still work.

---

## 7. help.feature

**What it tests:** Help/version/usage text, command summary.

**Flow:** No Session involved. Pure CLI output.

**Hex-pkg behavior required:** None.

**What breaks with ClaudePort:** Nothing.

**Risk:** TRIVIAL

**What to verify:** Help text displays.

---

## 8. log.feature

**What it tests:** Log retrieval (last 1, N, all), formatted output.

**Flow:** `CallHandler.handle(:log)` → `LogHandler` → read `state.messages` (persisted tuples).

**Hex-pkg behavior required:** None directly. Messages are stored by El, not hex pkg.

**What breaks with ClaudePort:** Nothing. Log is independent.

**Risk:** TRIVIAL

**What to verify:** Log shows correct messages.

---

## 9. model.feature

**What it tests:** Model flag (`-m sonnet`), default model from env (haiku tag), explicit model check.

**Flow:** `el <name> -m <model>` → Session.init passes `model: <model>` to `claude_module.start_link` → hex pkg picks model → Init message includes it.

**Hex-pkg behavior required:**
- Accept `model:` opt in start_link
- Use it for session initialization
- Reflect back in Init message

**What breaks with ClaudePort:**
- ClaudePort.init must accept and honor `model:` opt (already does: passes to CLI via Input.user_message or claude command).
- **Check**: Does `claude -m <model>` work? Or is it set via env/config? (Likely needs CLI flag pass-through.)

**Risk:** MODERATE (model flag plumbing through to claude CLI must work)

**What to verify:** Model flag respected end-to-end (ask returns correct model).

---

## 10. msg.feature

**What it tests:** Single message ask/response, multi-turn conversation (knock-knock), response stored in log.

**Flow:** `CallHandler.handle({:ask, message})` → `Claude.ask_work` → stream to result → store message entry → reply.

**Hex-pkg behavior required:**
- ClaudeCode.Message.ResultMessage struct with `result:` field
- Stream of events from `stream/2`
- Session persists across asks (stateful Port)

**What breaks with ClaudePort:**
- `El.Session.Claude.stream_to_result` pattern matches `ClaudeCode.Message.ResultMessage{result: result}`. **MUST CHANGE**: ClaudePort returns `{result, model, session_id}` tuple directly; no Message struct. `El.Session.Claude.stream_to_result` must detect backend and call `El.ClaudePort.ask` or `El.ClaudeCode.stream` appropriately. **OR** ClaudePort wraps ask result in a Message struct (boilerplate).
- **Stateful Port**: ClaudePort already holds session_id internally; multi-turn works by keeping Port alive. **Check**: Does it preserve context across asks? (Yes, Port holds state.)

**Risk:** HARD

**What to verify:** Multi-turn conversation works; responses appear in log with correct model/session_id.

---

## 11. restart.feature

**Status:** Already green (special case per brief).

**What it tests:** Session restart (crash recovery), context preserved.

**Flow:** `El.restart` command → `El.Application.restore_sessions` → re-read persisted messages → start new Session with `continue: true, agent: <agent>` → Session.init calls `Session.Claude.resume_options` → adds `:session_id` + `:resume` to opts → claude_module.start_link gets resume hint.

**Hex-pkg behavior required:**
- `resume: <session_id>` opt is passed to ClaudeCode.Session.start_link
- ClaudeCode.Adapter.Port (or equivalent) calls `claude -c <session_id>` to resume
- Session context is restored by Claude CLI

**What breaks with ClaudePort:**
- Resume is already partially implemented on wip. **Check**: Does `El.ClaudePort.init` extract `:resume` and pass to claude? (Yes, it does: `resume_id = Keyword.get(opts, :resume)`.)
- **But**: Does `claude -c <resume_id>` actually work? (Assumption: yes, it's Claude CLI's contract.) **Or** does it need different flag like `--resume` or just session context? (TBD — test against actual claude CLI.)

**Risk:** MODERATE (depends on actual `claude -c` behavior; already on wip, likely tested)

**What to verify:** Restart restores context (ask on restarted session returns answer mentioning previous context).

---

## Summary Matrix

| Feature | Risk | Core Blocker | Implementation |
|---------|------|--------------|-----------------|
| agent   | HARD | Model extraction from Init | ClaudePort must parse Init, return model |
| card    | MOD  | Model in metadata | Flows from agent.feature |
| clear   | TRI  | None | GenServer stop works |
| el2el   | TRI  | None | Independent |
| exit    | TRI  | Port cleanup | Port exit_status handling |
| glob    | TRI  | None | Independent |
| help    | TRI  | None | Independent |
| log     | TRI  | None | Independent |
| model   | MOD  | CLI flag plumbing | Pass `-m` to claude cmd |
| msg     | HARD | Message struct dispatch | Session.Claude must detect backend, wrap response or call differently |
| restart | MOD  | Resume flag behavior | Assume `claude -c` works (needs validation) |

**Top 3 challenges:**
1. **msg.feature (HARD)**: Session.Claude.stream_to_result pattern matches ClaudeCode.Message.ResultMessage. Must branch on module or restructure.
2. **agent.feature (HARD)**: Extract model from Init message (no struct in ClaudePort baseline).
3. **model.feature (MODERATE)**: Ensure `-m <model>` flag reaches claude CLI correctly.

---

## Path Forward

1. **Extract model from Init in ClaudePort.ask**: Parse first JSON line for `{"type":"init","session_id":"...","model":"..."}`, return `{result, model, session_id}`.
2. **Dispatch in Session.Claude**: `stream_to_result` must call either `El.ClaudeCode.stream` (hex) or `El.ClaudePort.ask` (direct). OR make ClaudePort return Message structs (boilerplate).
3. **Test model flag**: Verify `claude -m <model>` is passed through ClaudePort.init → claude CLI.
4. **Validate restart**: Run restart.feature against actual claude CLI to confirm `claude -c <id>` works.
