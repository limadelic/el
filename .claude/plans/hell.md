# El hell — stability plan

## Why this exists

Cucumber tests are flaky. The cause is unclear. Confidence in the boot pipeline (mix release → restart → daemon spawn → env propagation → claude API call) is low end-to-end. Cannot ship features on a foundation we don't trust.

## Confidence audit (snapshot)

| Piece | Confidence | Why |
|-------|-----------:|-----|
| `./el exit` does NOT kill daemon | 95% | Script reads as: rpc to running daemon, calls `exit_all` → `lifecycle.ex` kills sessions only. No `pkill beam.smp` in that path. |
| `./el restart` DOES kill daemon | 95% | Script does `bin/el stop` + `pkill -f beam.smp.*el_dev@` + `pkill -f epmd.*-port 4371` + sleep. Verified PID change via `ps`. |
| `mix release --overwrite` actually rebuilds | 70% | Output silenced in env.rb. Trust the exit code but never watched it produce a fresh binary. |
| Env vars propagate cucumber → daemon | 65% | Logical chain holds (shell → bundle exec → ruby → backtick → bin/el daemon). Never dumped the env from inside a cucumber-spawned daemon to confirm. |
| End-to-end test stability | 50% | 1/3 to 2/3 pass rate. Most failures are Claude self-identifying as Sonnet in prose despite likely running as Opus. Could be dispatch or could be hallucination. Not investigated on the wire. |

## Gaps to close

1. **Dump cucumber-spawned daemon's env on boot.** Write to `/tmp/el_daemon_env.log` from `application.ex` start. Compare to interactive shell daemon. Confirm propagation OR find the leak.
2. **Capture real model on the wire.** At message-time, log `Init.model` and `ResultMessage.model_usage` keys. That's the truth. Compare against agent.md `model:` and what we requested.
3. **Stop using Claude prose for assertions.** Tests asking "what model are you?" are testing Claude's self-introspection, not our dispatch. Replace with metadata-based assertions (the card's `model:` field).
4. **Make `./el restart` watch its work.** After kill + rebuild, verify the daemon is actually down (no PID matches), abort if not.

## Action plan

- [ ] Write daemon env to `/tmp/el_daemon_env.log` on boot
- [ ] Run cucumber, diff that file vs interactive daemon's env
- [ ] Add `model:` extraction from Init to session state (already prototyped tonight, was reverted)
- [ ] Rewrite agent.feature assertions to use card metadata, not Claude prose
- [ ] Add invariant check: assert daemon PID changed after `./el restart`

## After this plan lands

- Card story (`el-card.md`) is buildable
- DRY refactors (`el-dry.md`) are safe to apply (we'll know if any break the pipeline)
- Confidence numbers above all move to >90%

## Why we keep fighting this project

The platform (claude-code) gives us almost no provenance. No "active agent", no honest model echo, no way to verify dispatch except by asking the model itself (which lies). Every test ends up reverse-engineering its own ground truth. Until we own the observability — env dumps, Init capture, wire-level model — we're flying blind. This plan is the runway.
