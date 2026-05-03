# El Fix

## Issues Found

### 1. Stale escript shadows brew install ✅
- Removed project root escript (v0.1.66) → /tmp/el-stale
- Removed ~/.mix/escripts/el (v0.1.72) → /tmp/el-stale-mix
- `which el` now resolves to brew at /opt/homebrew/bin/el

### 2. `el <name> <msg>` shows old usage ✅
- Was caused by stale escript. Brew version has correct unified msg command.
- Help feature passes.

### 3. `kill all` doesn't kill ✅
- Added kill(:all) clause in El that iterates local_ls() and kills each session
- Uses Enum.reject(&(&1 == :all)) to prevent recursion
- Shipped in v0.1.75

### 4. Running daemon is stale ✅
- Killed old daemon (v0.1.66 from _build/prod/rel/), started fresh from brew
- Added VersionWatcher GenServer that auto-restarts daemon on version mismatch
- Checks every 60s, calls :init.restart() if installed != running
- Shipped in v0.1.76

### 5. Escript vs Release confusion ✅
- Escripts removed, brew release is the only distribution
- Published to hex.pm as "el" v0.1.75

### 6. PATH has project dir twice
- Still there but harmless now — no escript to shadow
- Could clean up later

## Also done
- Published to hex.pm (claimed "el" name)
- Added HEX_API_KEY to env
- Removed :sasl startup (not in deps, caused warning)
- Fixed test hang from Mimic.copy(:init) and Mimic.copy(Process)
