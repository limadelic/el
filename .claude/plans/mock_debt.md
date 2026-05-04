# Mock Debt — El

Punch list for replacing bare unsafe calls with `@behaviour` + Mox seams. Every module mocks the **next module** (one layer down). Modules outside our codebase, or ours that touch FS / network / DB / clock / processes / global state / external sandbox, MUST sit behind a behaviour and get a Mox double for unit specs.

---

## Audit summary

**Already correct (don't touch):**

| Caller | Behaviour | Mock | Field |
|---|---|---|---|
| `El.ClaudePort` → Port primitives | `El.Behaviours.Port` | `El.MockPort` | `state.port_module` |
| `El.PTY` → Port + File | `El.Behaviours.Port`, FileSystem | `El.MockPort`, `El.MockFileSystem` | opts |
| `El.Session.Store` → DETS write | `El.Behaviours.Store` | `El.MockStoreModule` | `state.store_module` |
| `El.AgentDetector` → File | `El.Behaviours.FileSystem` | `El.MockFileSystem` | `Application.get_env` |
| `El.SessionMeta` (DETS) | (struct mock) | `El.MockSessionMeta` | `state.session_meta` |
| `El.ClaudeCode` → ClaudeCode dep | `El.Behaviours.ClaudeCodeSession` | `El.MockClaudeCodeSession` | opts |
| `El.DetsBackend` → `:dets` | `El.Behaviours.Dets` | `El.MockDets` | `Application.get_env` |
| `El.Session` → Session.Ask collaborator | `El.Behaviours.SessionAsk` | `El.MockSessionAsk` | `state.ask_module` |

---

## P0 — Active leaks (cause timeouts, integration leaks, or just broke something)

Rule: mock the **next** module the caller actually calls. No invented intermediary roles.

| File:Line | Calls | Violates (Feathers) | New Behaviour | Adapter Module | Rationale |
|---|---|---|---|---|---|
| `lib/el/session/ask.ex:23` | `Claude.ask_work(state.claude_pid, message, routes)` where `Claude = El.Session.Claude` | Process | `El.Behaviours.SessionClaude` | `El.Session.Claude` | The next module is `El.Session.Claude`. Add behaviour with `ask_work/3` (and `ask/2`, `start/2`, `safe_reply/2` for full surface). Inject `state.claude_session` defaulting to `El.Session.Claude`. Ask spec stubs `MockSessionClaude.ask_work/3` — no Port, no CLI, no timeout. |
| `lib/el/session/tell.ex:31` | `Claude.ask(state.claude_pid, message)` where `Claude = El.Session.Claude` | Process + Clock | `El.Behaviours.SessionClaude` (same as P0#1) | `El.Session.Claude` | Same next-module seam. Reuses the behaviour from P0#1 — `ask/2` is already in scope. Tell spec stubs `MockSessionClaude.ask/2`. |
| `lib/el/process_monitor.ex:6` | `receive ... after 5000 -> cleanup(name)` | Clock | `El.Behaviours.Monitor` (already declared in `behaviours.ex:27`, not used here) | `El.MonitorImpl` | Wall-clock 5 s. Spec for `wait_for_down/2` would block. Wire it through `Behaviours.Monitor` (mock already exists in test_helper) and inject. |
| `lib/el/cli/daemon_connector.ex:5` | `:timer.sleep(100)` in retry loop | Clock | `El.Behaviours.Sleeper` (new) | `El.SleeperImpl` | 30 retries × 100 ms = 3 s wall-clock per spec. Inject a sleeper so test passes `NoopSleeper`. Trivial behaviour: `sleep(integer) :: :ok`. |
| `lib/el/session/router.ex:47,89` | `GenServer.cast(Registry.via_tuple(target), ...)` | Process + Global | `El.Behaviours.SessionApi` (already exists) | `El.Session.Api` | Router talks to live registered processes by name. Replace bare cast with `state.session_api.tell/cast` (route through the existing `MockSessionApi` seam). |
| `lib/el/session/router.ex:72,79` | `El.ask(target, ...)`, `El.tell(target, ...)` | Process + Global | `El.Behaviours.El` (already exists, `MockEl` in test_helper) | `El` | Direct module ref. Add `el_module` to Session state and thread through Router. Currently bypasses every test seam. |

## P1 — Lurking (passes today only because of accidental setup)

| File:Line | Calls | Violates (Feathers) | New Behaviour | Adapter Module | Rationale |
|---|---|---|---|---|---|
| `lib/el/cli/daemon.ex:84,90` | `System.cmd("epmd", ...)`, `System.cmd("sh", "-c ...")` | Sandbox + Global | `El.Behaviours.System` (new) | `El.SystemImpl` | Spawns external processes. Any spec touching `connect_to_daemon` or `start_daemon_node` shells out today. Behaviour: `cmd(binary, [binary]) :: {binary, integer}`. |
| `lib/el/cli/daemon.ex:27,69,35` | `Node.set_cookie/1`, `Node.connect/1`, `:net_kernel.start/1` | Global + Net | `El.Behaviours.Node` (new) | `El.NodeImpl` | Mutates real distributed-Erlang state. Two bad outcomes in tests: leaks cookie to other tests, or fails because epmd not running. Behaviour: `set_cookie/1`, `connect/1`, `start/1`. |
| `lib/el/cli/start.ex:67–73` | `File.open("/dev/null")`, `Process.group_leader/2`, `File.close/1` | FS + Global | reuse `El.Behaviours.FileSystem` + new `El.Behaviours.GroupLeader` | `El.GroupLeaderImpl` | `quiet_ask/1` mutates global IO. Already on the long-function refactor list (#7) — extract `with_silenced_io/1` and put both calls behind seams in the same TCR cycle. |
| `lib/el/cli/start.ex:257` | `Process.sleep(:infinity)` | Clock | `El.Behaviours.Sleeper` (new, see P0#4) | `El.SleeperImpl` | `hold_forever/0`. Production-only path, but if any spec calls `start_daemon_node_for/3` it hangs. Reuse the Sleeper from P0#4. |
| `lib/el/application.ex:67` | `File.mkdir_p!(Path.expand(dir))` | FS | reuse `El.Behaviours.FileSystem` (extend with `mkdir_p!/1`) | `El.FileSystemImpl` | Boot-time disk write. `init_message_store/0` is also on the long-function list (#9) — fold the FS extension into that cycle. |
| `lib/el/claude_code.ex:12,26,68` | `Application.get_env(:claude_code, :cli_path, ...)` and `:el, :claude_code_session_module, ...)` | Global | inject via opts | n/a | Runtime config lookup hides dependencies. Fold into call args (already partially done with `opts[:session_module]` — finish the job, drop the Application.get_env fallbacks). |
| `lib/el/agent_detector.ex:28` | `Application.get_env(:el, :file_system, ...)` | Global | already has `El.Behaviours.FileSystem` | n/a | Same anti-pattern at point of use. Default the param at the public-fn arity instead of resolving from app env on every call. |
| `lib/el/session.ex:87` | `Application.get_env(:el, :file_system, ...)` inside `init` | Global | already has `El.Behaviours.FileSystem` | n/a | Mirror of the above in Session init. Pull from `opts` only; default at construction time, not call time. |
| `lib/el/cli/start.ex:23,140` | `Application.get_env(:el, :agent_detector, ...)`, `:session_api, ...)` | Global | already have behaviours | n/a | Same. Move defaults to function head, drop runtime lookup. |
| `lib/el/message_store.ex` (whole module) | `:dets.close(:message_store)` and friends | DB | `El.Behaviours.MessageStore` (new — separate from `Behaviours.Store` which is high-level) | `El.MessageStoreImpl` | Module is the primitive DETS adapter under `El.Application`. No behaviour declared, no Mock. `MockStoreModule` covers the high-level entry API but not the DETS adapter primitives. |

## P2 — Pure modules incorrectly skipped

None found. Pure data shapers stay pure: `El.ClaudePort.Parser`, `El.Session.Router.detect_routes/1`, `El.Session.Id`, `El.CLI.Pattern`, `El.Credo.*`, the `add_*` helpers in `El.CLI.Start`, `El.Session.Store.replace_ask`. Don't put behaviours on these — they have nothing to mock.

---

## Principles (the why)

**Kent Beck / GOOS (Freeman & Pryce) — London school of TDD, with El's "no chain cojones" amendment:**

> Mock the **next** module the caller calls. One seam at the boundary you actually cross. Don't invent intermediary roles to feel pure — that just adds modules without removing dependencies. The interface still belongs to the consumer (named in the consumer's vocabulary), but it sits on the next real module, not on a phantom adapter.

> A unit test that needs a timeout has the wrong mock — not the wrong architecture.

**Feathers' five rules of unit testing (a unit test does NOT):**

1. Talk to the **filesystem**
2. Talk to the **network** / sockets
3. Talk to the **database** (DETS, ETS, SQL, anything persistent)
4. Depend on the **clock** (sleep, after, wall-clock timeouts)
5. Touch **processes outside the unit** / shared global state

**El's rules of thumb:**

- Every module mocks its **next** module (one layer down). Not two layers, not an invented role — the next real module.
- If the next module touches any of the five forbidden things, it MUST sit behind a `@behaviour` with a `Mox.defmock` in `test_helper.exs` and an injection point on the caller's state.
- `Application.get_env` at *call time* is mock debt. Resolve at construction time and pass through.
- A timeout in a spec is a confession. Fix by stubbing the next module, not by raising the timeout.
