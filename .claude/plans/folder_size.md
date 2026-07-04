# FolderSize follow-ups

`El.Credo.FolderSize` enforces 3 ≤ .ex files per folder ≤ 13.

## Config

`.credo.exs`:

```elixir
{El.Credo.FolderSize, [exempt: ["lib"], exempt_names: ["behaviours"]]}
```

- `exempt: ["lib"]` — package root (`lib/el.ex` only).
- `exempt_names: ["behaviours"]` — any folder with `behaviours` as a path segment. Behaviours dirs mirror their impl folder; refactor the impl, the behaviours follow.

## Outstanding LEAVE-AS-FINDING folders

These are real namespaces flagged by the check. Don't exempt — revisit when scope changes.

| Folder | Files now | Note |
|---|---|---|
| `lib/el/cli/daemon` | 2 (connection.ex, env.ex; sibling `behaviours/`) | Real namespace, grows with daemon work. |
| `lib/el/platform` | 2 (code.ex, parser.ex; sibling `behaviours/`) | Same shape as cli/daemon. |
| `lib/el/session/claude` | 2 (driver.ex, opts.ex) | Cohesive but thin. Revisit when claude/ grows or shrinks. |
| `lib/el/session/commands` | 2 (ask.ex, tell.ex) | Command-pattern namespace, grows with commands. |

Re-evaluate when any of these folders gain/lose a file.
