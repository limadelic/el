# El: Replacing `claude_code` Hex Package with `El.ClaudePort`

Feature-by-feature break analysis. Goal: identify what hex-pkg behavior each feature depends on, what would break with hand-rolled Port wrapper, and risk level for replacement.

---

## 1. agent.feature

**What it tests**: Agent name mapping (kent → opus, lisa → sonnet, etc.) and explicit `-a` flag override.

**Hex-pkg dependency**: Agent selection via `ClaudeCode.Session.start_link({..., agent: "kent", ...})`. The hex pkg passes agent string to CC CLI, which selects the agent. Init message streams back with agent context baked in.

**What breaks with El.ClaudePort**: Port wrapper must:
- Accept `:agent` option during init and pass it to `claude` CLI via stream-json
- Return Init message containing agent identifier so El can validate or log it

Currently El doesn't parse agent from response—it's baked in opts. Risk: **MODERATE**. Need to ensure `El.ClaudePort` pipes agent to CLI and verifies it took hold (or we lose agent context on restart).

**Verify**: Agent name resolves to correct model (kent=opus, lisa=sonnet) after switching from hex to Port.

---

## 2. card.feature

**What it tests**: Session info card display (name, agent, model, msg count, last prompt/response).

**Hex-pkg dependency**: Model name extracted from `ClaudeCode.Message.SystemMessage.Init{model: model}` stream event. Session ID also extracted from Init message.

**What breaks with El.ClaudePort**: Port wrapper must emit an Init-like event containing:
- `:model` (string like "claude-3-5-haiku")
- `:session_id` (unique ID for resumption)

Currently `El.Session.Claude.stream_to_result/2` pattern-matches `ClaudeCode.Message.ResultMessage` and `ClaudeCode.Message.SystemMessage.Init`. With Port, must parse JSON events from Port and extract same fields.

Risk: **TRIVIAL**. Just a struct → JSON event decode swap. Same fields.

**Verify**: Card displays correct model and session_id after Port replacement.

---

## 3. clear.feature

**What it tests**: `el donny clear` wipes conversation history, session_id resets, next message starts fresh.

**Hex-pkg dependency**: 
- `El.Session.Ask.reset_session/1` calls `Claude.start(...)` to spawn fresh Claude process.
- `Claude.stop_claude/1` calls `GenServer.stop(pid)` on the hex pkg session.

**What breaks with El.ClaudePort**: Port wrapper must support:
- Stopping (kill the Port process)
- Restarting fresh (spawn new Port)

Port.ex likely already has this (stop Port, start new one). Continuity: session_id must regenerate on restart.

Risk: **TRIVIAL**. Port lifecycle is simpler than hex pkg (just spawn/kill Port). 

**Verify**: Clear wipes messages, new message uses fresh session_id.

---

## 4. el2el.feature

**What it tests**: Inter-session routing (tell/ask between @name routes). Feature is currently **commented out** in el2el.feature.

**Hex-pkg dependency**: None directly. Routing logic lives in `El.Session.Router`. 

**What breaks with El.ClaudePort**: Nothing. This is pure El orchestration, not Claude-specific.

Risk: **TRIVIAL**. Independent of claude wrapper.

**Verify**: N/A (feature not active).

---

## 5. exit.feature

**What it tests**: `el donny exit` terminates session, `el exit` terminates all sessions.

**Hex-pkg dependency**: 
- `Claude.stop_claude(pid)` calls `GenServer.stop(pid)` on hex pkg process.
- Supervisor must trap exits and clean up.

**What breaks with El.ClaudePort**: Port wrapper must properly clean up when stopped. Port processes auto-close on gen_call/1 exit, but we must verify:
- Port closes cleanly
- No orphaned `claude` processes left behind
- Session cleanup in `:terminate` fires correctly

Risk: **MODERATE**. Port cleanup is simpler than hex pkg but needs testing. Orphaned processes are a risk.

**Verify**: After exit, no stray `claude` processes linger. `ps aux | grep claude` shows none.

---

## 6. glob.feature

**What it tests**: Pattern matching on session names (`donn*` matches donny/donner). Glob operations: exit, clear, log on multiple sessions.

**Hex-pkg dependency**: None. Glob matching is pure El logic in CLI layer. Each matching session spawns its own Claude process.

**What breaks with El.ClaudePort**: Nothing. Glob loops over session names, each session has its own Port. No shared state.

Risk: **TRIVIAL**. Independent of claude wrapper.

**Verify**: Glob clear/log operate on multiple sessions correctly.

---

## 7. help.feature

**What it tests**: Usage text and version display.

**Hex-pkg dependency**: None.

**What breaks with El.ClaudePort**: Nothing.

Risk: **TRIVIAL**.

**Verify**: Help text displays. Version shows.

---

## 8. log.feature

**What it tests**: `el donny log [n|all]` retrieves conversation history from store.

**Hex-pkg dependency**: None directly. Messages are stored locally in El, not in hex pkg.

**What breaks with El.ClaudePort**: Nothing. Log is pure El storage logic.

Risk: **TRIVIAL**.

**Verify**: Log displays correct messages.

---

## 9. model.feature

**What it tests**: Model selection via `-m` flag and environment default. Model is captured in response.

**Hex-pkg dependency**:
- Model passed to `ClaudeCode.Session.start_link({..., model: "haiku", ...})`.
- Model echoed back in Init message stream event.

**What breaks with El.ClaudePort**: Port wrapper must:
- Accept `:model` option during init and pass to `claude` CLI
- Return Init event with `:model` field

Currently `El.Session.Claude.extract_model/1` pattern-matches `ClaudeCode.Message.SystemMessage.Init{model: model}`. With Port, parse JSON Init event and extract model.

Risk: **TRIVIAL**. Same swap as card.feature. JSON event → struct decode.

**Verify**: Model flag sets correct model. Info card shows right model.

---

## 10. msg.feature

**What it tests**: Send message, get response, verify conversation continuity (multi-turn).

**Hex-pkg dependency**:
- `El.ClaudeCode.stream(pid, message)` returns enumerable of `ClaudeCode.Message` structs.
- `El.Session.Claude.stream_to_result/2` consumes enum, pattern-matches `ClaudeCode.Message.ResultMessage` to extract result text.

**What breaks with El.ClaudePort**: Port wrapper must:
- Expose a `.stream(port_pid, message)` or `.ask(port_pid, message)` API returning results, model, session_id.
- Or: return a stream/enum of JSON events that El parses for result, model, session_id.

Currently the code does: `El.ClaudeCode.stream(pid, message) |> Enum.to_list() |> find_value(&extract_result/1)`.

If El.ClaudePort returns `{result, model, session_id}` tuple (simpler), need to adapt `stream_to_result/2` or create new path.

Risk: **MODERATE**. This is the hot path. Streaming must not block. If Port.stream returns a synchronous tuple, may lose incremental streaming behavior (if that's desired). Current code collects all events then extracts final result—this works with Port too, but loses streaming UX (no progressive output).

**Verify**: Message sends, response returns correctly. Multi-turn context preserved.

---

## 11. restart.feature

**What it tests**: `el restart` kills all sessions cleanly, preserves session IDs and context, next message resumes conversation.

**Hex-pkg dependency**:
- Session ID captured at start (from Init message).
- Session ID persisted to `El.SessionMeta` store.
- On restart, session ID loaded and passed to `ClaudeCode.Session.start_link({..., resume: session_id, ...})` to resume CC session.

**What breaks with El.ClaudePort**:
- Port wrapper must support `:resume` option and pass to `claude` CLI.
- CC CLI must honor resume flag and reconnect to prior session.
- Port wrapper must return session_id from Init event on resume (or persist separately).

**Currently**: `CastHandler.handle({:complete_ask, ..., session_id}, state)` stores session_id via `session_meta.insert(...)`. On next init, `El.Session.Claude.resume_options(opts, session_id)` adds `:resume` to opts.

Risk: **HARD**. Resume is a seam in CC that El relies on. If Port doesn't expose resume or if CC CLI resume is flaky, this breaks silently (session context lost).

**Verify**: After restart, next message in same session resumes prior conversation (cite prior context).

---

## Summary Risk Table

| Feature | Risk | Dependency | Blocker |
|---------|------|-----------|---------|
| agent | MODERATE | Agent passed to CLI, validated in response | Need Init event with agent field |
| card | TRIVIAL | Model/session_id in Init event | JSON parse instead of struct match |
| clear | TRIVIAL | Process stop/start, session_id regenerate | Port lifecycle |
| el2el | TRIVIAL | None (pure routing) | None |
| exit | MODERATE | Clean Port shutdown, no orphans | Test process cleanup |
| glob | TRIVIAL | None (pure pattern matching) | None |
| help | TRIVIAL | None | None |
| log | TRIVIAL | None (local store) | None |
| model | TRIVIAL | Model passed to CLI, in Init event | JSON parse instead of struct match |
| msg | MODERATE | Stream enum consumption, result extraction | Adapt to tuple or JSON events |
| restart | HARD | Resume flag, CC CLI session resumption, ID persistence | CC CLI must expose resume semantics |

---

## Key Seams to Check in El.ClaudePort

1. **Init Message**: Must include `{:model, "..."}, {:session_id, "..."}` or equivalent JSON. 
2. **Result Extraction**: Must return or stream result text, model, session_id tuple.
3. **Resume Flag**: Must pass `resume: session_id` to `claude` CLI and reconnect.
4. **Process Cleanup**: Must kill Port cleanly on exit.
5. **Agent Field**: Must pass and echo back agent selection.

---

## Recommended Approach

- **Trivial** features (7): No verification needed, swap is mechanical.
- **Moderate** features (3): Verify Port init event schema, process cleanup, streaming behavior.
- **Hard** features (1): Verify CC CLI resume flag works, session context persists.

Build El.ClaudePort as a drop-in for `El.ClaudeCode` at the module level (same API: `start_link/1`, `stream/2` or direct `ask/1`). Adapt `El.Session.Claude.stream_to_result/2` or create a wrapper to parse Port output as JSON events or tuples. Test restart end-to-end.
