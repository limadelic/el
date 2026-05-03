# El Restart Plan

## PROBLEM

After `brew upgrade el`, the daemon still runs old code. New `el` CLI calls connect to the stale daemon via RPC and get old behavior. Killing the daemon loses all running sessions.

## GOAL

Seamless upgrade: new code, sessions survive.

## WHAT WE KNOW

### Current architecture
- Daemon is a long-lived escript process at `el@127.0.0.1`
- Sessions are GenServers under DynamicSupervisor in the daemon
- Each session owns a Claude Port (persistent stdin/stdout pipe to `claude` CLI process)
- Claude CLI uses `--resume <session_id>` to reload conversation from JSONL on disk
- DETS at `~/.el/messages.dets` stores El-level message history (separate from Claude's JSONL)
- `El.ls()` returns list of running session names

### What survives a restart
- Claude conversation history — persisted as JSONL at `~/.cache/claude/<session_id>.jsonl`
- El message log — persisted in DETS at `~/.el/messages.dets`
- Session names — stored in DETS (keys are `{name, ...}` tuples)

### What dies on restart
- GenServer state (in-memory messages, pending_calls)
- Claude Port process (OS subprocess killed)
- In-flight requests (pending ask/tell calls)

## ROUGH APPROACH

### Option A: Restart command
```
el restart
```
1. `El.ls()` → collect running session names
2. For each session: grab session_id from GenServer state
3. Kill daemon (or hot-reload code?)
4. Start fresh daemon with new code
5. Re-start each session with saved session_id → `--resume` picks up conversation

### Option B: Hot code reload
- Erlang supports hot code loading natively
- Escript complicates this — code is embedded in the binary
- Would need to extract new beam files from new escript and load them
- Complex but zero-downtime

### Option C: Formula post_install with state file
1. Before kill: dump running sessions to `~/.el/restart.json` (names + session_ids)
2. `post_install` kills daemon
3. Next `el` call: daemon starts, checks `~/.el/restart.json`, re-starts saved sessions
4. Delete restart.json after restore

## OPEN QUESTIONS

- Can we read session_id from DETS without a running GenServer? (avoids needing the daemon alive to dump state)
- Should `el restart` be a CLI command or automatic on version mismatch?
- What happens to pending asks/tells during restart? Drop them? Queue them?
- Option B feasibility — has anyone hot-reloaded an escript before?
- Should the daemon embed its version and refuse RPC from mismatched clients?

## STATUS

Parked — iron out in next convo.
