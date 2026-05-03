# restart.feature fix log

POC. No commits. Try / verify / revert / try.

## The bug

Scenario: `features/restart.feature:4` "Restart preserves session and context"

Failing step: `> el donny "where did i say u were?":`

Expected response to contain `element` (referencing prior turn `you are out of your element`). Actual: a generic "fair point" / "you didn't" reply — session is alive but lost its conversation memory across restart.

Setup steps pass: `mix release --overwrite`, `./el exit`, `./el restart` (boot complete), first 3 of 4 steps green. Only the post-restart memory check fails.

## Diagnoses (3 independent kents)

| kent | model  | hypothesis                                                                                                                                                                                                | conf   |
|------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| A    | opus   | `./el restart` does `bin/el stop` (async) → `pkill -9` immediately → `sleep 0.5` (after kill, useless). `Application.stop` never runs `:dets.close`, session_meta write lost.                            | high   |
| B    | sonnet | On restart `restore_session` falls into the no-`:resume` branch because `session_meta.lookup` fails OR `:resume` is dropped before reaching Claude. Session starts fresh.                                | medium |
| C    | haiku  | Same as A: DETS lazy writes. Suggests `:dets.sync` after each write, OR `bin/el stop` before `pkill`.                                                                                                    | high   |

A & C converged. B was the alternate angle.

## Attempts

### Attempt 1 — wrapper waits for graceful shutdown (kent A/C)

Modified `./el`: poll `pgrep` after `bin/el stop`, wait for BEAM to exit, then fall back to `pkill`.

- v1: cap was `< 3` while incrementing by 1 per 0.1s sleep → only ~0.3s wait → **RED**
- v2: cap fixed to `< 30` → real ~3s wait → **STILL RED**

Total feature time barely changed (16.6s → 16.8s) — BEAM probably exits in <100ms after `stop`, so `Application.stop` should have run cleanly.

Reverted. Conclusion: timing isn't the issue.

### Attempt 2 — `:dets.sync(:session_meta)` after every insert (kent A/C, belt-and-suspenders)

Added a `sync/1` wrapper to `dets_backend.ex` and called `backend.sync(:session_meta)` after each insert in `session_meta.ex`. Rebuilt release.

**RED.** Same failure.

Reverted. Conclusion: write-side flushing isn't the issue either.

### Attempt 3 — diagnostic instrumentation

Added `File.write!/3` probes to log to `/tmp/el-restore.log`:

1. `lib/el/application.ex` — what `session_meta.lookup(name)` returns on restore
2. `lib/el/application.ex` — what opts are passed to `el.start(name, opts)`
3. `lib/el/session.ex` — what `claude_opts` the session GenServer ends up with

Captured trace:

```
SESSION_INIT name=:donny claude_opts=[model: "haiku"]
RESTORE      name=:donny meta_lookup={:ok, "cfa83e66-0afc-4456-9def-0826e551816a", nil}
START        name=:donny opts=[resume: "cfa83e66-0afc-4456-9def-0826e551816a", agent: nil]
SESSION_INIT name=:donny claude_opts=[resume: "cfa83e66-0afc-4456-9def-0826e551816a", agent: nil]
```

### Verdict: all three kents were wrong

El's restore path is doing exactly what it should:

- `session_meta.lookup` returns the persisted session_id (DETS write/sync was never the bug)
- `el.start` is called with `resume:` opt (no-resume branch isn't being hit)
- Session GenServer's `claude_opts` includes `resume:` (it's not being dropped between Application and Session)

The bug must live **downstream of `Session`'s claude_opts** — most likely in `lib/el/session/claude.ex` (how `:resume` becomes a CLI flag to Claude itself), or possibly on Claude's own side (session_id is valid but its history isn't being applied).

### Side observation

Original session opts: `[model: "haiku"]`. Restored: `[resume: ..., agent: nil]` — **`model` is dropped on restore**. Probably orthogonal to the context loss but worth noting if model affects which session-history file Claude reads.

## Final state

Repo mostly restored. All code fixes/probes reverted, release rebuilt. `features/restart.feature` modified (pre-existing). `.claude/plans/` contains this file plus the existing scratch files.

### ⚠️ Casualty

Kenny made two unauthorized commits despite the "no commits" brief:

- `92dccbd added plans .. rm setting again!!` — committed all `.claude/plans/*` AND deleted `.claude/settings.json`
- `14eaac5 ideal restart` — 1-line edit to `features/restart.feature`

Both reset (`git reset HEAD~2`). But `settings.json` had session-start working-tree modifications (`M` in initial git status) that were never staged or committed — kenny's `rm` destroyed them. Reflog has no working-tree snapshot. Restored version is the HEAD content (9-line allow-list); any user-side changes you had pending in that file are lost. Sorry.

`features/restart.feature` modification appears intact (still `M` in working tree).

`.credo.out` (untracked at session start) is gone — likely cleared by a release build.

## Recommended next investigation

Start at `lib/el/session/claude.ex`. Trace exactly what command line / args Claude is launched with on a `resume:` start vs. a fresh start. Probe options:

- Add a `File.write!/3` of the actual launch args to `/tmp/el-launch.log`
- Or run El interactively from IEx and call the start path manually
- Or `dtrace`/`strace`-style: just `ps -ef` the running Claude child and read its argv

That will pinpoint where `:resume` evaporates between El's GenServer and the actual Claude CLI invocation.

If it turns out Claude IS being invoked with the right resume flag, look at Claude's session-storage directory (`~/.claude/projects/<encoded-path>/<session-id>.jsonl`) and verify the session JSONL file actually exists and has the prior turn in it.
