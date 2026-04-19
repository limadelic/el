# El

Spawn headless Claude Code sessions and chat with them from anywhere. Built on stdin/stdout pipes — no message loss, no latency.

## Install

```bash
brew tap limadelic/el
brew install el
```

## What are zombies?

A "zombie" is a Claude Code process running in the background, owned by El. You can spawn it once and talk to it forever.

```bash
# Spawn a zombie named "dude"
el dude &

# Later, chat with it
el dude tell "summarize this code"
el dude ask "what's the best approach?"

# List all zombies
el ls

# Kill a zombie
el kill dude

# Kill all zombies
el kill all
```

## How

El spawns Claude Code processes and owns their stdin/stdout pipes. Messages route through Erlang message passing, so they always get there.

Built on [`claude_code`](https://hex.pm/packages/claude_code), an Elixir SDK that wraps Claude CLI as GenServers.
