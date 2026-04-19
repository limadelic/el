---
name: el
description: Use el CLI to manage agents instead of Agent/Team tools
---

# El — Agent Control Plane

Use `el` to manage Claude Code sessions as your dev team. No Agent tool, no TeamCreate, no SendMessage.

## Commands

| Action | Old Way | El Way |
|--------|---------|--------|
| Spawn agent | `Agent(subagent_type: "kent")` | `el kent &` |
| Send work | `SendMessage(to: "kent")` | `el kent tell "fix the bug"` |
| Ask question | `Agent(prompt: "...")` | `el kent ask "what model r u using"` |
| Check history | _(no equivalent)_ | `el kent log` |
| Kill agent | `SendMessage(shutdown_request)` | `el kent kill` |
| List agents | _(read team config)_ | `el ls` |
| Kill all | _(loop shutdown requests)_ | `el kill all` |

## The Loop

1. `el <name> &` — start a session (zombie mode)
2. `el <name> tell <work>` — fire-and-forget task
3. `el <name> ask <question>` — wait for answer
4. `el <name> log` — review what happened
5. `el <name> kill` — done with this agent

## Rules

- Use `el` via Bash tool — these are real shell commands
- `tell` = fire-and-forget (long tasks, edits, builds)
- `ask` = wait for response (questions, status checks)
- Quote messages with special chars: `el kent ask "what's the status?"`
- Avoid `?` unquoted — zsh treats it as glob
- One session per name — `el kent &` twice reuses the existing one
- `el ls` shows active sessions, `(name)` means dead process
- `el log` is your audit trail — use it to verify work

## Anti-Patterns

- DO NOT use Agent tool — use `el <name> &` + `el <name> tell`
- DO NOT use TeamCreate — sessions ARE the team
- DO NOT use SendMessage — use `el <name> tell` or `el <name> ask`
- DO NOT spawn throwaway agents — el sessions persist and remember
- DO NOT fire and forget — check `el <name> log` to verify work
