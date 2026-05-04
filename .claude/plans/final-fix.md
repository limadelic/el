# El Final Fix

Consolidates el-fix.md and el-resilience.md. One plan to rule them all.

## What Was Wrong (the week of pain)

1. Stale escript shadowed brew install → FIXED (v0.1.75)
2. Sessions died when Claude crashed → FIXED (trap_exit + dets)
3. Messages lost on VM crash → FIXED (dets persistence)
4. nohup daemon killed VM on stderr write → FIXED (mix release + daemon)
5. eval wrapper caused fragile custom discovery code → FIXED (switched to rpc)
6. VersionWatcher couldn't detect upgrades → **THIS IS THE LAST ONE**

## The Bug (VersionWatcher)

`installed_version()` was structurally broken. RELEASE_ROOT resolves symlinks
to the physical cellar path at startup (`/opt/homebrew/Cellar/el/0.1.80/...`).
After `brew upgrade`, the new version lives at a NEW cellar path. The running
process reads start_erl.data from the OLD path. Comparing old vs old. Could
never detect an upgrade.

The WIP brew cmd approach (`System.cmd("brew", ...)`) works but shells out
every 60 seconds. Both approaches are wrong because the watcher itself is
unnecessary.

## The Fix

Delete VersionWatcher. Handle restart at install time via formula `post_install`.

1. Add `post_install` to `rel/formula.rb.template` — `quiet_system libexec/"bin/el", "stop"`
2. Delete `lib/el/version_watcher.ex`
3. Delete `specs/el/version_watcher_spec.exs`
4. Remove `El.VersionWatcher` from children in `lib/el/application.ex`
5. Revert WIP changes on the branch

## Why This Works (all verified via www)

**post_install stops the old daemon:**
- Cookie is hardcoded to `"el"` in env.sh.eex (same across all versions)
- `el stop` calls `System.stop()` on remote node via RPC
- `System.stop()` terminates heart before halting (no zombie restarts)
- If daemon not running, quiet_system ignores the failure
- :dets flushes to disk on graceful shutdown

**Brew upgrade sequence (confirmed via Homebrew source):**
- install new → unlink old → link new → post_install → cleanup
- Symlinks point to new version BEFORE post_install runs
- No race condition

**Wrapper auto-starts the new daemon:**
- User runs `el <command>` after upgrade
- Wrapper resolves symlinks → follows to new cellar path
- Tries RPC → daemon not running → starts daemon → retries (10x, 0.5s)
- New daemon runs from new version. Done.

**Sessions survive:**
- Sessions trap exits via `Process.flag(:trap_exit, true)`
- Messages persist to :dets at `~/.el/messages.dets`
- :dets auto-repairs on ungraceful kill
- Claude Code child processes die via normal process cascade

## Unknowns (ALL RESOLVED)

- [x] Does `el stop` also stop heart? YES
- [x] What happens to active sessions? Graceful shutdown, dets persists
- [x] Does brew remove old cellar immediately? NO, cleanup is later
- [x] Race condition in post_install? NO, linking happens before
- [x] Cookie mismatch between versions? NO, hardcoded to "el"
- [x] Does quiet_system exist in Homebrew? YES, suppresses errors

## Already Done (from el-fix + el-resilience)

- [x] Stale escript removed (v0.1.75)
- [x] Mix release replaces escript
- [x] nohup replaced with release daemon
- [x] :dets message persistence
- [x] SASL crash logging
- [x] Heart auto-restart
- [x] Homebrew tap updated for release tarball
- [x] eval → rpc in wrapper (except --version which is fine)
- [x] find_daemon_node, check_daemon_version, Node.connect — all deleted
- [x] kill(:all) support (v0.1.75)

## Still Open (not this fix, future)

- PATH has project dir twice (harmless)

## Changes

| File                              | Action                                                        |
|-----------------------------------|---------------------------------------------------------------|
| rel/formula.rb.template           | Add post_install with `quiet_system libexec/"bin/el", "stop"` |
| lib/el/version_watcher.ex         | DELETE                                                        |
| specs/el/version_watcher_spec.exs | DELETE                                                        |
| lib/el/application.ex             | Remove El.VersionWatcher from children list                   |
