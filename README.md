# El

*The telepathic bridge between Claude processes. El Dude abides.*

Claude Code agents can't talk to each other reliably. The inbox polling drops messages, the file-based messaging breaks across backends. Nobody in the wild has multi-agent Claude workflows working as a daily driver.

Turns out the problem is receiving, not sending. And the only reliable port is stdin — zero latency, always available, no feature flags. You just have to own the process.

So that's what El does. It spawns Claude processes, owns their stdin/stdout pipes, and routes messages between them. Session A says something to Session B, and it actually gets there. Every time.

## How

Built on top of [`claude_code`](https://hex.pm/packages/claude_code) — an Elixir SDK that already wraps Claude CLI as GenServers via Erlang Ports with bidirectional NDJSON streaming. All the hard plumbing is done. El just adds the horizontal layer: sessions talking to sessions.

```elixir
# Start two named sessions
{:ok, _} = El.start(:alice, system_prompt: "You are Alice")
{:ok, _} = El.start(:bob, system_prompt: "You are Bob")

# Alice talks to Bob
El.tell(:alice, :bob, "knock knock")
```

That's it. Two BEAM processes, two Claude processes, one message.

## Why Elixir

GenServer wrapping a Port is the most classic Erlang pattern there is. The BEAM gives us process isolation, supervision (crash = restart), and free inter-process messaging. We don't need a message broker, a queue, or an API. Just processes talking to processes.

## Lineage

El is a seed of [Elita](https://github.com/limadelic/elita) — the full agentic platform. Patterns learned here feed into Elita later. El solves the immediate problem: make multi-agent Claude work today.
