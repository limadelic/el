# El Instability Archaeology

Synthesis of recurring themes from 10 plan documents spanning El development.

## Document Summary

| File | Date | Symptom | Fix/Status |
|------|------|---------|-----------|
| el-hell.md | Apr 30 | Flaky cucumber tests, low confidence in boot pipeline | Audit plan: dump daemon env, capture model metadata, rewrite assertions |
| el-zombie.md | Apr 20 | Discovery phase for multi-session architecture | Design complete, code scaffolding in place (GWT started) |
| el_zombie_discovery.md | Apr 20 | Same as above | Same as above |
| el-resilience.md | Apr 24 | Sessions die unconditionally; messages lost on VM crash; crashes cascade | Identified root cause: eval (not rpc) forces custom fragile discovery code; planned dets persistence + supervision fixes |
| el-restart.md (v1) | Apr 26 | Daemon stuck after brew upgrade; new CLI runs old code | Option A/B/C analysis parked; open questions list |
| el_restart.md (v2) | Apr 29 | Stale processes block every rebuild; DETS lock, zombie heart restarts | Kill-clean-start strategy: fix wrapper, remove heart, close DETS on shutdown |
| el-fix.md | Apr 25 | Stale escript shadows brew install; bad daemon version; kill(:all) broken | Fixed: removed escripts, added VersionWatcher (auto-restart on mismatch), added kill(:all) support |
| el-final-fix.md | Apr 25 | VersionWatcher itself broken; release path mismatch after upgrade | Root cause: symlink resolves to old cellar path; delete VersionWatcher, use Homebrew post_install instead |
| el-resume.md | Apr 30 | In-flight TCR loop for session restart/persistence | 7-step breakdown: SessionMeta facade → capture session_id at init → restore on app start → atomic delete → verify crash survival → verify resume wiring |
| el-agent-investigation.md | Apr 29 | `-a kent` flag path fails with "thinking.type.enabled not supported"; implicit paths work | 6 theories tested/disproven; circling diagnosis: likely state.opts vs state.claude_opts mismatch on respawn (unverified) |

---

## Top 3 Recurring Symptoms

1. **Process/daemon restart chaos** (appears in: restart v1, restart v2, fix, final-fix)
   - Stale daemon after upgrade; old code runs; manual `pkill` needed every rebuild
   - DETS file locks block shutdown; zombie processes from heart flag; EPMD orphans
   - VersionWatcher tries and fails to detect upgrades (symlink trap)

2. **Message loss and session death cascade** (appears in: hell, resilience, restart)
   - Sessions die unconditionally when Claude crashes (trap_exit not set)
   - VM crash from stderr badarg wipes all ETS in-memory message history
   - One session crashing triggers supervisor cap-out (10/30s) → kills all other sessions

3. **Flaky test assertions and observability gap** (appears in: hell, agent-investigation)
   - Cucumber tests assert Claude's prose ("what model are you?") instead of metadata
   - No way to verify which model actually ran on the wire
   - CLI `-a` path behaves differently than implicit path for same agent (unresolved)
   - Daemon env propagation untested; boot pipeline confidence at 50%

---

## Top 3 Recurring Root Causes Hypothesized

1. **Eval instead of RPC for CLI dispatch** (identified in: resilience)
   - Each `el` CLI command spawns a fresh BEAM VM with no apps/state
   - Forced custom discovery code (file-based daemon node lookup, version checking, Node.connect)
   - All that custom code is fragile and keeps breaking
   - Switching to RPC would delete ~200 lines of cli.ex; daemon node discovery automatic

2. **Missing persistence layer** (identified in: resilience, restart)
   - ETS message store survives session crash but not VM crash
   - DETS solution implemented but needs tight integration: message writes per Claude message, session_id/agent metadata capture on init, graceful DETS close on shutdown
   - Without it, crash → data loss → no recovery → sessions unrestorable

3. **No production-grade deployment hooks** (identified in: final-fix, restart)
   - Brew formula had no post_install; stale daemon kept running after upgrade
   - Heart flag respawned killed processes as zombies; System.restart() kept old code paths
   - RELEASE_ROOT symlink resolution trapped at startup (could not detect new version)
   - Solution: lean on Homebrew post_install (already built, just needed wiring) and graceful shutdown via RPC

---

## Pattern Analysis

**Same bug surfacing differently?** Yes — process/daemon restart is the core instability.
- Apr 26: daemon stuck after upgrade (restart v1)
- Apr 29: stale processes block every rebuild (restart v2)
- Apr 25: VersionWatcher tries and fails to auto-detect
- Apr 25: final-fix says delete VersionWatcher, use post_install

Each approach tried to solve "how do we run new code?" but missed the deployment seam (post_install hook).

**Different bugs sharing a theme?** Yes — persistence and graceful shutdown.
- Messages lost (ETS only, no DETS)
- Sessions die unconditionally (no trap_exit)
- DETS locks block shutdown (no close callback)
- VersionWatcher stuck in loop (can't detect change)

All stem from: "we don't remember state across restarts, and we crash messy."

**Genuinely separate issues?** The agent `-a` flag investigation (apr 29) appears orthogonal — opts shape mismatch on respawn, unverified. Not persistence, not deployment, not restart. Different family of bugs.

---

## Implementation Status (from el-final-fix + el-resume)

**Already shipped (v0.1.75–0.1.80):**
- Stale escript removed
- Mix release replaces escript
- nohup → release daemon
- DETS message persistence (basic)
- SASL crash logging
- Heart auto-restart
- eval → rpc for CLI (except --version)
- kill(:all) support
- kill/stop custom discovery code

**In flight (from el-resume TCR loop, 7 steps):**
- SessionMeta facade (TODO #39) — capture session_id + agent at birth
- Restore flow — replay saved sessions with `--resume` on daemon restart
- Atomic delete — both message_store and session_meta cleared on explicit exit
- Crash survival verification — meta persists across non-normal exits
- Resume wiring — verify `:resume` reaches Claude

**Open (from el-agent-investigation):**
- `-a kent` path produces different opts than implicit kent (root cause unverified)
- Likely state.opts vs state.claude_opts mismatch in `maybe_respawn_claude`
