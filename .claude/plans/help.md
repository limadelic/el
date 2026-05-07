# Help Plan

Gap list between `features/help.feature` and current implementation.

## Not Implemented

1. **`-json` flag** — on `el <name>` (info) and `el <name> log`. No handler. Defer until needed: 3 router routes + JSON formatter (likely new `El.CLI.Output.Json` module under London harness).

## Already Working

- `el -v`, `el ls`, `el exit`, `el clear`
- `el <name> start [-m model] [-a agent]`
- `el <name> <msg>`
- `el <name>` → info (alive ? info : usage)
- `el <name> log [n]`, `el <name> log all`
- `el <name|glob> clear`, `el <name|glob> exit`, `el <name|glob> restart`, `el <name|glob> log [n|all]`
- `el restart` → daemon restart (kills daemon BEAM + all `claude` subprocesses; `Restorer.restore_sessions` rehydrates every session from DETS on boot — strict superset of "restart all sessions")
