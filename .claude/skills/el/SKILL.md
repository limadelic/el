---
name: el
description: Use when delegating to another dude via "el <agent>"
---

# El

## What

- CLI for talking to other dudes
- The `el` subagent owns the CLI, you don't

## How

- Delegate via the `el` subagent (Agent tool, `subagent_type: el`)
- Background the call
- One message per invocation, spawn fresh each time
- Tell it WHO and WHAT, never HOW
- Ask one question at a time

## NEVER

- Never call `el` via Bash
- Never wrap `el` in any other agent
- Never SendMessage the `el` subagent
- Never kill it, it is one-shot, let it finish
- Never block
- Never one-shot complex issues
- Never ask for logs unless troubleshooting
