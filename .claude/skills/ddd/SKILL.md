---
name: ddd
description: Dude-Driven Development — discovery through build with glossary maintenance
---

# DDD (Dude-Driven Development)

## Domain

Three layers, one domain:

1. **El** (~/dev/self/el/) — the Elixir/OTP control plane. This is what we're building. The BEAM-powered shell that Dude runs on.
   - Spawns and manages Claude processes via Erlang Ports and PTY
   - Routes messages between agents via distributed Erlang
   - Commands agents programmatically (skills, config, restart)
   - Supervises sessions with OTP (crash detection, restart, health)
   - Built on the `claude_code` hex package
2. **Dude** (~/.claude/) — the product layer. Skills, agents, commands, workflows. El serves Dude.
   - **Dude gem** (~/.claude/code/) — Ruby gem with CLI and domain code
   - Global config, plans, teams — all under ~/.claude/
3. **Claude Code** at ~/dev/ext/claude-code/ (READ ONLY) — the platform underneath. We reverse engineer CC to discover what it exposes. We NEVER modify CC — we build around it in El.

To act as domain expert: www the CC docs AND read the CC source for the right terms. But solutions always land in El.

## Code vs Shell

El is Elixir/OTP — the control plane. Shell scripts are fine for POCs but ultimately the logic moves to Elixir modules — keeps the model simple and leverages OTP guarantees. Skills/agents/commands delegate to El, not the other way around.

## GOAL

- Discover and develop a DSL.
- Terms come from the domain, not from code or frameworks.
- You (CC, Dude, El) are the domain expert.
- www in your docs (CC) for the right terms.
- Glossary maintenance is part of EVERY loop, not an afterthought.

## Ubiquitous Language

- **dude** — an agent session, the product, the whole project
- **el** — the shell, the Elixir/OTP control plane that dude runs on
- **session** — a managed Claude process inside the BEAM
- **node** — an Erlang node running El
- **abide** — an agent listening for work
- **pub** — register a dude in the global registry
- **unpub** — tear down a dude from the registry
- **sub** — register as a private dude under a pub
- **tell** — send a message, no reply expected (`El.tell/3`)
- **ask** — send a message, reply expected (`El.ask/3`)
- **inbox** — where messages land for a dude
- **watch** — listen for new messages in an inbox
- **reply** — respond to an ask, continues the conversation
- **abided** — done with a message, clear inbox
- **headless** — a session without interactive terminal (GenServer only)
- **pty** — a session with full TUI via pseudo-terminal

## The Loop

### 0. Three Amigos (optional, recommended)

Run `/three-amigos` to discover WHAT before writing scenarios.

### 1. GWT

Run `/gwt` — the full scenario-by-scenario loop with Lisa and Eric.

## Glossary Maintenance

**Who**: Eric flags, Dude decides
**When**: During each loop (steps 2, 3, 5)
**Where**: Ubiquitous Language section above
**Commit**: Glossary updates ship with the feature
