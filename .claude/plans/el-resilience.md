# El Resilience

> **I've been failing at this for a whole week.**
> Do NOT claim shipped/done until the human explicitly confirms it works.
> Only the human decides when this is shipped. Not me. Not a plan file. Not a checklist.

## WHAT

1. Sessions never die from the user's perspective
2. If they crash, they come back with their full message history
3. Crash reason is visible in `el lisa log`
4. One session crashing never kills another

## WHY (verified by Kent + Eric)

### WHY 1: Sessions die

- session.ex:321 — EXIT handler returns {:stop, reason, state} when Claude dies. Session dies with Claude unconditionally.
- application.ex:15 — DynamicSupervisor max_restarts: 10, max_seconds: 30. If 10 crashes in 30s, supervisor itself dies, taking ALL sessions.
- cli.ex:58 — daemon sleeps forever with Process.sleep(:infinity). Can't recover from supervisor death.
- cli.ex:608 — daemon spawned with nohup > /dev/null 2>&1. stderr device doesn't exist, VM crashes on any error write (badarg in io:put_chars). This kills the ENTIRE daemon, not just one session.

### WHY 2: Messages don't survive

- ETS table :message_store owned by Application (application.ex:24). Survives individual session crashes.
- BUT: ETS is in-memory only. When the VM crashes (WHY 1 — stderr kills the VM), ALL ETS data is lost.
- No disk persistence (:dets, mnesia, files) exists anywhere. Messages live only in RAM.
- "Persist FOREVER until kill" requires :dets — ETS is not enough.

### WHY 3: Crash reason not visible

- session.ex:315 — EXIT handler logs crash reason to Logger.error (goes to stderr/console)
- session.ex:321 — returns {:stop, reason, state} WITHOUT storing crash reason in state.messages
- session.ex:236-238 — :log handler returns state.messages, but session is dead after {:stop} so it can never be called
- Crash reason goes to Logger (stderr → /dev/null → void). Never stored in messages. `el lisa log` can't show what killed it.

### WHY 4: One crash kills others — TWO mechanisms

**Mechanism A: Supervisor restart limits**
- application.ex:15 — DynamicSupervisor max_restarts: 10, max_seconds: 30
- If 10+ sessions crash in 30s, DynamicSupervisor itself crashes
- Application supervisor (one_for_one at line 20) sees DynamicSupervisor die
- All sessions under DynamicSupervisor are torn down

**Mechanism B: VM crash from stderr**
- cli.ex:608 — nohup > /dev/null 2>&1 makes stderr unavailable
- Any error write (Logger, IO, crash report) triggers badarg in io:put_chars
- Entire BEAM VM crashes — ALL sessions die, ALL ETS data lost
- This is what the erl_crash.dump showed

## HOW (all verified via www)

### Mix Release
- El becomes a mix release (not escript)
- -detached for daemonization (no nohup, no stderr crash)
- SASL for automatic crash/restart logging
- Heart for VM auto-restart
- Homebrew: tarball on GitHub, formula unpacks + symlinks

### :dets for message persistence
- One :dets table, type :bag, keyed by session name
- Session writes every message to :dets
- Session reads from :dets on init (restart recovery)
- Crash reason written to :dets before session stops
- el name kill deletes session's :dets entries
- Built-in OTP, zero deps, survives VM restarts

### Supervision
- DynamicSupervisor one_for_one (already set)
- GenServer default restart: :permanent (already the default)
- SASL logs every crash and restart automatically
- config :logger, handle_sasl_reports: true

## TASKS (for katmandu — after all WHYs verified)

1. ✅ DONE — Switch from escript to mix release (mix.exs, rel/ config, remove escript config)
2. ✅ DONE — Replace nohup spawn_daemon with release daemon command (cli.ex)
3. ✅ DONE — Add :dets message persistence to Session (session.ex, application.ex)
4. ✅ DONE — Update Homebrew tap for release tarball distribution
5. ✅ DONE — Update bob agent commands for release build pipeline

## ROOT CAUSE (Kent, verified via www)

The wrapper uses `eval` instead of `rpc`. This is the source of ALL the custom fragile code.

- `eval` starts a SEPARATE BEAM VM with no apps, no state, no distribution
- Every CLI command (`el ls`, `el dude tell`) spins up a fresh VM
- That VM needs custom code to discover and connect to the daemon
- This custom code (file-based discovery, Node.connect, version checking) keeps breaking

**The fix**: use `rpc` which connects to the running daemon via EPMD automatically.

### What to delete (all unnecessary with rpc)
- cli.ex ~200 lines: find_daemon_node, check_daemon_version, daemon_node file, Node.connect, retry logic
- application.ex: maybe_write_daemon_node, daemon_version file
- el_wrapper: version checking lines 11-18

### What to change
- el_wrapper: `eval "El.CLI.dispatch([...])"` → `rpc "El.CLI.dispatch([...])"` 
- spawn_daemon: use release `daemon` command directly, not nohup

### What to keep
- Mix release, dets persistence, SASL, Heart, supervision tree
- Session GenServer, crash logging in EXIT handler

## STATUS

NOT SHIPPED. Root cause identified: eval vs rpc. Custom discovery code must be replaced with standard OTP patterns. Human has not confirmed anything works.
