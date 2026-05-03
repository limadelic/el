# El Restart: Tame the Beast

## Problem

Every rebuild/install/feature change, the El daemon gets stuck. Manual `pkill -f beam.smp; pkill -f epmd` required every time. Root causes (confirmed by 6 independent investigations):

1. `el_wrapper restart` calls `System.restart()` which restarts the VM but keeps OLD release code paths — new binary never loads
2. `-heart` flag respawns killed BEAM processes as zombies with old code
3. EPMD orphans — custom EPMD daemons (4370/4371) never cleaned up on stop
4. DETS file lock not released on shutdown — no `stop/1` callback

## Strategy: Kill, Clean, Start

No magic. No soft restarts. No version detection. Three small edits.

### Task 1: el_wrapper restart — kill-clean-start
**File:** `rel/overlays/bin/el_wrapper`

Replace restart block. Stop beam, kill stale processes by node name, kill EPMD on port, sleep 0.5, rebuild if DEV, start daemon fresh. Use clean if/else for EPMD_PORT and RELEASE_NODE.

### Task 2: Remove heart
**File:** `rel/env.sh.eex`

Change `export ELIXIR_ERL_OPTIONS="-heart"` to `export ELIXIR_ERL_OPTIONS=""`.

### Task 3: Close DETS on shutdown
**File:** `lib/el/application.ex`

Add `stop/1` callback: `:dets.close(:message_store)`. Add test in `specs/el/application_spec.exs`.

## Process

Katmandu: one task at a time, Kenny codes + TCR, Cartman reviews after each.