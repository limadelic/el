# Feature-by-Feature Breaking Analysis: Ripping Out claude_code Hex Pkg

## Current State
- `El.ClaudeCode` wraps `ClaudeCode.Session.start_link/stream` (hex pkg public API)
- `El.Session.Claude` pattern matches on `ClaudeCode.Message.ResultMessage` and `ClaudeCode.Message.SystemMessage.Init` structs
- `El.ClaudePort` exists on wip branch: spawn `claude` CLI with stream-json in/out, return `{result, model, session_id}` from `ask/2`
- Mix dep: `:claude_code ~> 0.36`

## Key Integration Points to Verify
1. **Message struct matching** in `El.Session.Claude` (lines 54-70): pattern matches on `ClaudeCode.Message.*` structs
2. **Streaming protocol** in `El.ClaudeCode.stream/2` -> `ClaudeCode.Session.stream/2`
3. **Session model/agent selection** in `El.ClaudeCode.build_final_opts/3` (lines 20-21)
4. **Resume semantics** in `El.ClaudeCode.add_resume_if_present/2` (lines 55-60)
5. **Permissions/settings** in `El.ClaudeCode` (lines 44-45) - dangerously skip, setting sources

---

## 1. agent.feature

**What it tests:**
- Explicit agent flag: `el kenny -a kent` -> expects agent: kent
- Implicit agent detection from name: `el kent:` -> expects agent: kent
- Model override: `el kent -m haiku` -> agent: kent, model: haiku
- Agent/model combo: `el lisa` -> agent: lisa, model: sonnet

**Hex pkg dependencies:**
- Agent selection: parsed by `El.ClaudeCode.build_final_opts/3` line 21 (`add_agent/2`)
- Passed to `ClaudeCode.Session.start_link/1` as `[agent: kent]` kwarg
- Hex pkg internally routes agent name to model mapping (kent -> opus, lisa -> sonnet)
- The hex pkg's `ClaudeCode.Session` struct itself carries agent/model metadata

**What breaks with El.ClaudePort:**
- `El.ClaudePort.ask/2` returns `{result, model, session_id}` but does NOT return agent name
- Agent selection still works (passed through `opts` to CLI) but agent is NOT extracted from response
- No struct to pattern match on; agent must be stored in local state or CLI must echo it back
- **Risk: MODERATE** - agent is passed correctly to CLI, but if feature expects agent echoed in response or retrievable from session struct, it breaks

**Verification:** Agent passed in CLI call is used correctly; agent is recoverable from state.opts or must be queried separately

---

## 2. card.feature

**What it tests:**
- New card display: `el kent:` shows name, agent, model, msg count, prompt/response
- Used card: tracks msg count (1 -> 2), shows conversation
- Anom card: unnamed session, defaults to haiku model

**Hex pkg dependencies:**
- **Agent name extraction:** Card calls `el kent:` which is a status query, not a message send
- Status is built in `El.Session.CallHandler.handle(:info, ...)` line 25-27
- `build_info/3` (line 35-45) extracts model from messages metadata: `Map.get(metadata, :model)`
- Model metadata comes from `{_type, prompt, response, metadata}` tuple stored in El.Application (line 44)
- The hex pkg provides model in Init message; El.Session.Claude extracts it (line 60-62)
- **Agent NOT in returned info** - it's pulled from `Keyword.get(state.opts, :agent)` in CallHandler.handle(:agent, ...)

**What breaks with El.ClaudePort:**
- El.ClaudePort.ask returns `{result, model, session_id}` - model IS extracted
- Model storage in metadata works the same (stored at ask completion)
- Agent in opts still works (stored at init, retrieved from opts)
- **Risk: TRIVIAL** - all card data is recoverable from state; no struct dependency

**Verification:** Model extracted from response, agent from opts; card renders without relying on hex pkg structs

---

## 3. clear.feature

**What it tests:**
- Send message `1 + 1`, view log, clear, re-view shows `(1 + 1)` (parenthesized = cleared)

**Hex pkg dependencies:**
- Clear action: `El.Session.CallHandler.handle(:clear, ...)` line 30-32
- Calls `Claude.stop_claude(state.claude_pid)` (line 31)
- `Claude.stop_claude/1` calls `GenServer.stop(pid)` (line 94)
- This calls the underlying hex pkg's session GenServer stop
- Then calls `Ask.reset_session(state)` which deletes message store and restarts
- **No pattern matching on hex pkg structs; purely process termination**

**What breaks with El.ClaudePort:**
- El.ClaudePort.stop_claude equivalent must stop the GenServer
- El.ClaudePort IS a GenServer so `GenServer.stop(pid)` works identically
- **Risk: TRIVIAL** - GenServer interface unchanged; clear logic unaffected

**Verification:** Process stop and message store reset work; log shows parenthesized messages after clear

---

## 4. el2el.feature

**What it tests:**
- Inter-session routing: `el donny tell @donnie <msg>` and `el donny ask @donnie <msg>`
- Feature is DISABLED (commented out in .feature file)

**Hex pkg dependencies:**
- Router logic in `El.Session.Router` (detect routes, process tell/ask between sessions)
- No hex pkg dependency in router; pure El logic for message routing
- Message storage/retrieval is El.Application responsibility

**What breaks with El.ClaudePort:**
- Nothing - feature is disabled
- When enabled, no breaking changes (no hex pkg structs involved)
- **Risk: N/A (disabled)**

**Verification:** N/A - feature off; no hex pkg dependency in routing logic

---

## 5. exit.feature

**What it tests:**
- List sessions: `el ls` shows (donny) = offline, donny = online
- Start session: `el donny` -> session live, `el ls` shows donny
- Exit session: `el donny exit` -> session dead, `el ls` shows (donny)

**Hex pkg dependencies:**
- Exit calls `El.Session.Terminator.handle(reason, state)` on GenServer exit
- Terminator must clean up port or session process
- Session lifecycle: GenServer.stop() is called by hex pkg's session (or El.ClaudePort equivalent)
- **No struct pattern matching; pure process lifecycle**

**What breaks with El.ClaudePort:**
- El.ClaudePort.exit equivalent must trigger terminate/2
- GenServer.stop(pid) will call terminate/2 on El.ClaudePort same as hex pkg
- **Risk: TRIVIAL** - process stop is identical; terminator doesn't depend on hex structs

**Verification:** Session termination cleanly stops Claude process; registry updates correctly

---

## 6. glob.feature

**What it tests:**
- Exit all: `el exit` terminates all sessions
- Pattern glob: `el donn* exit` exits donny + donner
- Clear glob: `el donn* clear` clears both sessions
- Log glob: `el donn* log` shows logs for matched sessions

**Hex pkg dependencies:**
- Glob expansion happens at CLI layer, routes to each session's GenServer
- Each session calls same handlers (exit, clear, log) independently
- **No hex pkg dependency; pure El.Session message dispatch**

**What breaks with El.ClaudePort:**
- Nothing - glob is CLI-level; each session call is independent
- **Risk: TRIVIAL** - no hex pkg struct dependency

**Verification:** Glob patterns correctly route to matched sessions; actions work on each

---

## 7. help.feature

**What it tests:**
- Help text: `el` or `el --nonsense` shows command reference
- Displays version, usage, available commands

**Hex pkg dependencies:**
- **NONE** - help is static CLI text from El.CLI

**What breaks with El.ClaudePort:**
- Nothing - pure CLI text
- **Risk: TRIVIAL**

**Verification:** Help text renders; version displayed

---

## 8. log.feature

**What it tests:**
- Log last (default): `el donny log` shows last message only
- Log N: `el donny log 2` shows last 2
- Log all: `el donny log all` shows all

**Hex pkg dependencies:**
- Log retrieval: `El.Session.CallHandler.handle(:log, ...)` calls `LogHandler.handle_log(msg, state)`
- Returns `state.messages` which are stored as `{type, prompt, response, metadata}` tuples
- Messages are stored in El.Application.store_message (DETS backend) during ask completion
- Model metadata comes from response (same for hex pkg or El.ClaudePort)
- **No struct pattern matching; pure tuple storage/retrieval**

**What breaks with El.ClaudePort:**
- Nothing - log format unchanged; metadata dict with model key still works
- **Risk: TRIVIAL** - log storage and retrieval is El-only, not hex pkg dependent

**Verification:** Log entries stored correctly; filtering by N works; all entries retrieved

---

## 9. model.feature

**What it tests:**
- Default model from environment: `el haiko` expects haiku model (from name or ENV)
- Explicit model flag: `el sonet -m sonnet` -> model: sonnet
- Query model response: "what model are you using?" -> "haiku"

**Hex pkg dependencies:**
- Model selection: parsed in `El.ClaudeCode.build_final_opts/3` line 20 (`add_model/2`)
- Passed to hex pkg's `ClaudeCode.Session.start_link/1` as `[model: haiku]`
- Model **returned in response**: extracted in `El.Session.Claude.stream_to_result/2` line 49
- Pattern matches on `ClaudeCode.Message.SystemMessage.Init{model: model}` (line 60)
- Stored in message metadata at `Ask.finalize_ask/6` -> metadata dict with :model key

**What breaks with El.ClaudePort:**
- El.ClaudePort.ask returns `{result, model, session_id}` - model IS included
- Model extraction works identically
- Model storage in metadata unchanged
- **BUT:** hex pkg may send model in Init message; El.ClaudePort parses stream-json and extracts it
- If stream-json format differs (e.g., key name), pattern match fails and model = nil
- **Risk: MODERATE** - model extraction depends on stream-json format matching expected keys

**Verification:** Model passed to CLI; stream-json Init event has "model" key; model extracted and stored correctly

---

## 10. msg.feature

**What it tests:**
- Single message: `el donny 1 + 1` -> response `2`
- Conversation: sequence of prompts, each continued from prior context

**Hex pkg dependencies:**
- Message send: `El.Session.CallHandler.handle({:ask, message}, ...)` calls `Claude.ask/2`
- `Claude.ask/2` calls `stream(pid, message)` -> `El.ClaudeCode.stream(pid, message)` -> `ClaudeCode.Session.stream(pid, message)`
- Hex pkg's stream/2 returns enum of messages
- `El.Session.Claude.stream_to_result/2` (line 46-51):
  - Converts enum to list: `Enum.to_list(events)`
  - Extracts result via `ClaudeCode.Message.ResultMessage` pattern match
  - Extracts model via `ClaudeCode.Message.SystemMessage.Init` pattern match
  - Extracts session_id via `ClaudeCode.Message.SystemMessage.Init` pattern match
- **CRITICAL BREAKING POINT:** Enum.find_value/2 with pattern match functions (lines 48-50)

**What breaks with El.ClaudePort:**
- El.ClaudePort.ask/2 directly returns `{result, model, session_id}` (no streaming)
- No Enum.to_list; El.ClaudePort handles streaming internally
- No pattern match on hex pkg structs; El.ClaudePort parses JSON and extracts values
- **El.Session.Claude.stream_to_result/2 is REPLACED entirely** - can't use hex pkg struct patterns
- El.ClaudePort.ask returns tuple directly; `Ask.spawn_ask` must be rewritten to not call stream_to_result
- **Risk: HARD** - core streaming + message parsing architecture must change
  - Stream enum -> direct tuple return
  - Hex pkg struct patterns -> direct dict/tuple extraction
  - Ask handler flow changes

**Verification:** Message sent, response received, model extracted, session_id persisted, conversation context maintained

---

## 11. restart.feature

**What it tests:**
- Restart session: `el restart` kills all sessions and reloads from disk
- Session context preserved: prior messages still in log
- Session context used: asking about prior context returns prior answer
- Special case: feature passes on current code; analyzes hex pkg dependency

**Hex pkg dependencies:**
- Restart flow:
  1. `El.Application.restore_sessions/0` (line 27-34) called on app startup
  2. Calls `session_meta.lookup(name)` to get `{:ok, session_id, agent}` or `{:error, not_found}` (lines 36, 41)
  3. If found: `el.start(name, continue: true, agent: agent)` calls session with `:continue` flag
  4. Session init passes `:continue` through to `build_claude_opts/3` -> `add_continue/2` -> claude_opts
  5. In `El.ClaudeCode.build_final_opts/3`, `:continue` is treated same as `:resume` (line 22)
  6. Passed to hex pkg's `ClaudeCode.Session.start_link/1` as `[continue: true]`
  7. Hex pkg reconnects to existing Claude session via resume/continue protocol
  8. Messages reloaded from El.Application.load_messages(name) (line 82)

**What breaks with El.ClaudePort:**
- El.ClaudePort.init receives opts including `:continue`
- `:continue` flag must be mapped to `--continue` or equivalent CLI arg (like `:resume` -> `--resume`)
- El.ClaudePort already handles resume: `Keyword.get(opts, :resume)` -> passed to CLI command
- **El.ClaudePort line 34 (in wip):** `resume_id = Keyword.get(opts, :resume)`
- **Missing:** `:continue` flag not extracted! Only `:resume` is handled
- If `:continue` is supposed to be same as resume but with different semantics, El.ClaudePort must extract it too
- **Risk: HARD** - if `:continue` and `:resume` are different (different CLI behavior), El.ClaudePort must map `:continue` -> resume_id or handle it specially
  - If they're the same: just extract `:continue` as well
  - If different: the restart feature will BREAK on El.ClaudePort because continue flag not passed

**Verification:** Session resumed with prior session_id; context available; continue behavior matches hex pkg's continue protocol

---

## Summary Risk Matrix

| Feature     | Risk  | Hex Pkg Dependency                              | Breakage Mode                                    |
|-------------|-------|------------------------------------------------|--------------------------------------------------|
| agent       | MODERATE | Agent name NOT in response; must be in opts   | Agent retrieved from opts, not response struct   |
| card        | TRIVIAL | Model in response metadata; agent in opts    | All data retrievable; no struct dependency       |
| clear       | TRIVIAL | GenServer stop                                | Process lifecycle identical                      |
| el2el       | N/A   | Disabled feature; no hex pkg involvement      | N/A                                              |
| exit        | TRIVIAL | GenServer terminate                           | Process lifecycle identical                      |
| glob        | TRIVIAL | CLI-level; each session independent           | No hex pkg dependency                            |
| help        | TRIVIAL | Static CLI text                               | No hex pkg dependency                            |
| log         | TRIVIAL | Message tuple storage; no structs             | Storage format unchanged                        |
| model       | MODERATE | Model key in stream-json Init event           | If key name differs, extraction fails            |
| msg         | HARD   | Hex pkg struct pattern matching in stream    | Entire ask -> stream -> extract flow changes     |
| restart     | HARD   | :continue flag handling; resume protocol     | If :continue != :resume, feature breaks         |

---

## Biggest Pain Points

1. **msg.feature (HARD):** `El.Session.Claude.stream_to_result/2` relies on `ClaudeCode.Message.ResultMessage` and `ClaudeCode.Message.SystemMessage.Init` pattern matches. These structs do not exist in El.ClaudePort. The entire streaming + parsing pipeline must be rewritten.

2. **restart.feature (HARD):** `El.ClaudePort` only handles `:resume` flag, not `:continue`. If they're semantically different, the restart flow breaks. Must verify what `:continue` means in hex pkg vs. hand-rolled Port wrapper.

3. **model.feature (MODERATE):** Model extraction depends on stream-json having a `"model"` key in the Init event with the right structure. If ClaudeCode.CLI outputs different JSON keys, pattern matching in El.ClaudePort must adapt.

4. **agent.feature (MODERATE):** Agent name is NOT returned from Claude; it lives only in state.opts. Feature should work but depends on agent being queryable from local session state, not from response struct.
