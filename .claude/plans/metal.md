# El Metal: Drop the `claude_code` Hex Pkg, Feature by Feature

## Where we are

- Repo: `/Users/maykel.suarez/dev/self/el`
- Branch `poc` (HEAD `bedc5f2`) — restart cuke green via `claude -c` warm-restart fix on top of the hex pkg. Hex pkg fully in use.
- Branch `wip` — has `lib/el/claude_port.ex` (a hand-rolled persistent Port wrapper around the `claude` CLI with stream-json in/out) plus parser fixes (`subtype` matcher, `:incomplete` return). NEVER wired into `Session.claude_module`. Not proven to green any cuke.
- Goal: replace `claude_code` Hex pkg with `El.ClaudePort` end-to-end. Drop the dep from `mix.exs`. Delete `lib/el/claude_code.ex`.

## The seam that matters

`lib/el/session/claude.ex` `stream_to_result/2` (lines 46–51) pattern matches on `ClaudeCode.Message.ResultMessage` and `ClaudeCode.Message.SystemMessage.Init` structs. `El.ClaudePort.ask/2` returns a plain `{result, model, session_id}` tuple — no structs. Until that bridge is rewritten, the Port path is dead code regardless of what `claude_module` is set to.

## Three kents agreed

- **TRIVIAL** (no hex pkg dependency, free passes once seam is fixed): help, log, glob, clear, el2el
- **MODERATE**: card (depends on model in metadata), model (`-m` flag plumbing), exit (Port cleanup, orphan `claude` processes)
- **HARD**: msg (the hot path that hits the struct-matching seam), agent (agent flag → CLI + agent in state), restart on Port (resume vs continue semantics)

Restart already greens on poc but via the hex pkg + `claude -c`. Once we swap to Port, restart needs re-verification.

---

## Phase 0 — Foundation (one fresh session)

Goal: get `El.ClaudePort` wired into Session as the `claude_module`, with a tuple-friendly `Session.Claude` bridge. No feature work yet — just plumbing.

1. Cherry-pick from `wip`:
   - `lib/el/claude_port.ex` (the Port GenServer)
   - The parser fixes for `claude_port.ex` (`subtype` not `message_type`; `process_lines` returns `:incomplete` when no result event seen)
2. In `lib/el/session.ex` line 15: change `claude_module: El.ClaudeCode` → `claude_module: El.ClaudePort`.
3. In `lib/el/session/claude.ex`:
   - Delete `stream_to_result/2`, `extract_result/1`, `extract_model/1`, `extract_session_id/1` (all hex-pkg-struct pattern matchers).
   - Rewrite `ask/2` to call `claude_module.ask(pid, message)` directly and return the `{result, model, session_id}` tuple.
4. Build, run `features/restart.feature` — must stay green (or surface what breaks).
5. Commit.

Exit criteria: `restart.feature` greens on the Port path. `lib/el/claude_code.ex` and the hex pkg are still present but only as fallback. Stop here for the session.

---

## Phase 1 — Feature-by-feature (one feature per fresh session)

Each step: one feature, run cuke, fix what breaks in `claude_port.ex` or `session/claude.ex`, commit, stop. Don't bundle.

### Step 1.1 — `features/restart.feature` (re-verify on Port)
Should be green from Phase 0. If not, it's the resume flag: `El.ClaudePort` honors `:resume` but maybe not `:continue`. Map `:continue` to whatever CLI flag the warm-restart path needs (`-c` vs `--resume <id>`). Likely 30 min.

### Step 1.2 — `features/help.feature` + `features/log.feature` + `features/glob.feature` + `features/clear.feature` + `features/el2el.feature` (the freebies)
Run them. Any that pass — done. Any that fail — likely a process-lifecycle bug in `ClaudePort` (terminate, port cleanup). Fix in `claude_port.ex`. Likely <1 hour total.

### Step 1.3 — `features/card.feature`
Verify model is flowing into the message metadata. The card reads `metadata[:model]`, which is set in `Ask.finalize_ask` from the model returned by `ask`. If model is nil, the bug is in `ClaudePort` Init parsing — confirm it extracts `model` from `{"type":"system","subtype":"init","model":"..."}`.

### Step 1.4 — `features/model.feature`
Verify `-m sonnet` passed via opts threads through to the `claude` CLI argv. Inside `ClaudePort`, the model option must become `--model <m>` (or whatever flag claude CLI uses). Check `Command.build_args` (or the inlined replacement) handles `:model`.

### Step 1.5 — `features/msg.feature`
The hot path — multi-turn conversation. Likely already works post-Phase 0 (Port holds session state across asks via persistent connection + resume). If it fails, the bug is either: (a) Port loses state between asks, or (b) result text not extracted from the result event. Use the `CLAUDEPORT_TRACE` Logger.error markers (already in `claude_port.ex`) to debug.

### Step 1.6 — `features/agent.feature`
Verify `-a kent` and implicit `el kent` route to the right model. Two parts: (a) agent option threads to CLI via `--agent <name>`, (b) agent is recoverable from `state.opts` for the info/card paths. ClaudePort already passes opts through; check the `Command.build_args` replacement handles `:agent`.

### Step 1.7 — `features/exit.feature`
The risky cleanup case. After `el donny exit`:
- Session GenServer terminates → `Terminator.handle` runs → must call `Claude.stop_claude(claude_pid)` (currently it doesn't).
- `ClaudePort.terminate/2` must close the Port and reap the `claude` child process.
- Verify `pgrep -f claude` shows no orphans after exit.

Likely the fix is in `lib/el/session/terminator.ex` (call `stop_claude`) and `lib/el/claude_port.ex` `terminate/2` (already calls `Port.close`, may need `:port_close` wait or explicit signal).

---

## Phase 2 — Drop the hex pkg (one fresh session)

Once all features green on the Port path:

1. Inline 5 helpers in `lib/el/claude_port.ex`:
   - `Command.build_args/3` → ~30 LOC private function building `claude` argv
   - `Input.user_message/2` → ~5 LOC building NDJSON `{"type":"user",...}`
   - `Parser.normalize_keys/1` → ~20 LOC recursive snake_case key normalizer (already in the code; could just keep using it from a copied module)
   - `Adapter.Port.Resolver.find_binary/1` → ~15 LOC `:os.find_executable("claude")`
   - `Adapter.Port.Installer.cli_not_found_message/0` → ~10 LOC OS-aware error string
2. Remove all `alias ClaudeCode.*` from `claude_port.ex`.
3. Delete `lib/el/claude_code.ex` (the wrapper).
4. Delete `lib/el/behaviours.ex` references to `ClaudeCode` if any.
5. Drop `{:claude_code, "~> 0.36"}` from `mix.exs`.
6. `mix deps.unlock --unused && mix deps.clean claude_code`
7. Run all features. Commit. Push.

---

## Risk hotspots (per kent consensus)

1. **`stream_to_result` rewrite** — Phase 0 blocker. Get this wrong and nothing past it works.
2. **Session resume** — `:continue` vs `:resume` semantics. ClaudePort must respect both.
3. **Orphan `claude` processes on exit** — `Terminator.handle` doesn't currently stop `claude_pid`. Will leak procs without a fix.
4. **Init message parsing** — claude CLI emits `{"type":"system","subtype":"init",...}`. The wip parser was fixed for this; make sure that fix lands in Phase 0.

## What this is NOT

- Not a rewrite of Session, Ask, CallHandler, etc. The seam is contained to `claude_port.ex` (rewrite) + `session/claude.ex` (delete struct matchers) + `session.ex` line 15 (default swap) + `mix.exs` (drop dep).
- Not 2–3 days. Phase 0 is a session. Each Phase 1 step is a session (some sessions can do multiple steps if the freebies stay free). Phase 2 is a session. So ~6–9 fresh sessions of focused work, each terminating with a green feature commit.
