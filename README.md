# El

Actor Model for Claude Code.

## Install

```bash
brew install limadelic/tap/el
```

## Features

| Feature           | CC | El + |
|-------------------|:--:|:----:|
| Headless sessions | ✅  |  ✅   |
| Agent config      | ✅  |  ✅   |
| Parallel work     | ✅  |  ✅   |
| Shell control     | ✅  |  🌱  |
| Task delegation   | ✅  |  🌱  |
| File-based        | ✅  |  ❌   |
| Event-driven      | ❌  |  ✅   |
| Cross-project     | ❌  |  ✅   |
| Peer-to-peer      | ❌  |  ✅   |
| Any shell         | ❌  |  🌱  |
| Codex peers       | ❌  |  🌱  |

✅ done 🌱 todo ❌ not done

## Help

```
> el
el -v                      version
el ls                      list sessions
el <name> [-m <model>]     start or status
el <name> tell <message>   fire-and-forget
el <name> ask <message>    wait for response
el <name> log              view log
el <name> kill             kill session
el kill all                kill all sessions
```
