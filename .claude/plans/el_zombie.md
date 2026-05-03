# El Zombie

*Headless Claude sessions managed by El. They work, they don't talk, they just do.*

## Goal

Multiple headless Claude sessions in one BEAM, reachable via distributed Erlang. No TUI, no shell — just work.

## What Works Today

- `El.start(:alice)` → starts a named headless session via `claude_code` hex
- `El.tell(:alice, "do this")` → fire-and-forget, returns immediately
- Distributed Erlang → `el tell alice "msg"` from any node
- Separate BEAM nodes per session (escript)

## What's Next

### 1. Multiple sessions in one BEAM
- One El node runs all headless sessions
- `el dude` → spawns a session in the running El
- `el elita` → spawns another, same BEAM
- Sessions are children of El's supervision tree

### 2. Supervision
- `ClaudeCode.Supervisor` already exists in the hex package
- Wire it into `El.Application`
- Crash = auto-restart, conversation resumed via `:resume`

### 3. El.tell and El.ask (Tell Don't Ask)
- `El.tell(:dude, msg)` — fire-and-forget (GenServer.cast), returns immediately, no response
- `El.ask(:dude, msg)` — blocks, waits for Claude response, returns text (GenServer.call)
- Both work local or remote (distributed Erlang)

### 4. Session registry
- `El.ls()` — list running sessions
- `El.status(:dude)` — alive? busy? idle?
- Use Elixir's built-in Registry

### 5. CLI commands
- `el <name>` — start a session in running El
- `el <name> kill` — stop a session
- `el <name> tell msg` — inject message
- `el <name> ask msg` — send and wait for response
- `el ls` — list running sessions
- `el <name> log` — view session logs

### 6. Integration with dude
- Dude (interactive Claude) delegates to zombies via Bash: `el dude tell go`
- Zombies work silently, dude checks results
- `/tell` skill updated to use El instead of file-based messaging

## Architecture

```
┌─────────────────────────────────────┐
│ El BEAM node (--sname el)           │
│                                     │
│  ┌─────────┐  ┌─────────┐          │
│  │ :dude    │  │ :elita  │  ...     │
│  │ GenServer│  │ GenServer│          │
│  │ (claude) │  │ (claude) │          │
│  └─────────┘  └─────────┘          │
│                                     │
│  Supervisor + Registry              │
└─────────────────────────────────────┘
        ↑                    ↑
   el dude tell         el elita tell
   (from dude or         (from anywhere)
    any node)
```

## Non-goals (for now)

- No TUI / PTY (that's el.sh, separate concern)
- No router (sessions don't talk to each other yet, dude routes)
- No web UI
- No fancy protocol — just GenServer calls
