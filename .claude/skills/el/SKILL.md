---
name: el
description: Use el CLI to manage agents instead of Agent/Team tools
---

# El - Agent Control Plane

Use `el` (brewed binary, `/opt/homebrew/bin/el`) to manage persistent Claude Code sessions. Use Agent tool for short-lived haiku workers.

> **NEVER use `./el`** - that's the dev escript. Always use the installed `el`.

## Commands

| Action | El Way |
|--------|--------|
| Spawn session | `el kent` |
| Send work | `el kent tell "fix the bug"` |
| Ask question | `el kent ask "what model?"` |
| Check history | `el kent log` |
| Kill session | `el kent kill` |
| List sessions | `el ls` |
| Kill all | `el kill all` |

## The Loop

1. `el <name>` - start a headless session (self-daemonizes, returns to shell)
2. `el <name> tell <work>` - fire-and-forget task
3. `el <name> ask <question>` - wait for answer
4. `el <name> log` - review what happened
5. `el <name> kill` - done with this agent

## Rules

- Use `el` via Bash tool - these are real shell commands
- `tell` = fire-and-forget (long tasks, edits, builds)
- `ask` = wait for response (questions, status checks)
- Quote messages with special chars: `el kent ask "what's the status?"`
- Avoid `?` unquoted - zsh treats it as glob
- One session per name - `el kent` twice reuses the existing one
- `el ls` shows active sessions
- `el log` is your audit trail - use it to verify work

## Who Gets an El Session

Persistent agents that need memory and long-running context:
- **kent**, **lisa**, **dude**, **liz**, **eric** — use `el <name>`

## Who Stays a Subagent

Short-lived haiku workers for quick tasks — use `Agent(subagent_type, model: "haiku")`:
- **kenny** — TDD coder
- **cartman** — code reviewer
- **bob** — build/test/git
- **arana** — web browser

## Anti-Patterns

- DO NOT use Agent tool for persistent agents — use `el`
- DO NOT use `el` for throwaway tasks — use Agent with haiku
- DO NOT fire and forget — check `el <name> log` to verify work
