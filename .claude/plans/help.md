# Help Plan

Gap list between `features/help.feature` and current implementation.

## Not Implemented

- `Output.usage_message` layout doesn't match the grouped sectioned block in `features/help.feature` (info/log with `[-json]`, `start [args]` with sub-args, `cmds:` group). Tracked as H7.
- README + `~/.claude/skills/el/` docs don't mention `-json`. Tracked as H8.

## Already Working

- `el -v`, `el ls`, `el exit`, `el clear`
- `el <name> start [-m model] [-a agent]` — explicit `start` keyword wired (H9)
- `el <name> <msg>`
- `el <name>` → info (alive ? info : usage)
- `el <name> [-json]` → JSON info (alive: full shape; dead: `{name, alive: false}`)
- `el <name> log [n|all]`, `el <name> log all`
- `el <name> log [n|all] [-json]` → JSON array of `{type, message, response, metadata}` (dead session → `[]`; H6/H11 pin)
- `el <name|glob> clear`, `el <name|glob> exit`, `el <name|glob> restart`, `el <name|glob> log [n|all]`
- `el restart` → daemon restart (kills daemon BEAM + all `claude` subprocesses; `Restorer.restore_sessions` rehydrates every session from DETS on boot — strict superset of "restart all sessions")
- Plain `el <name> log` gated on `alive?` — dead session prints "No sessions running" instead of crashing (H10)
