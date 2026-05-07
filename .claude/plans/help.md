# Help Plan

Gap list between `features/help.feature` and current implementation.

## Not Implemented

1. **`-json` flag** — on `el <name>` (info) and `el <name> log`. No handler.
2. **`log all`** — router only handles `[name, "log", n]`; no "all" branch.
3. **`el <name>` → info** — currently routes to `:start`. Help advertises info.
4. **`restart`** — absent from router and dispatch. Per-session and daemon-wide both missing.
5. **`el <cmd>` (apply to all)** — only `exit` wired (`:exit_all`). Missing: `clear` all, `restart` all.
6. **glob on `log`** — `clear`/`exit` use `Pattern`; `log` doesn't, so glob on log is not wired.

## Already Working

- `el -v`, `el ls`, `el exit`
- `el <name> start [-m model] [-a agent]`
- `el <name> <msg>`
- `el <name> log [n]` (single name)
- `el <name|glob> clear`, `el <name|glob> exit` (via Pattern)
