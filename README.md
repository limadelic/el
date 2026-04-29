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
el -v                        version
el ls                        list sessions
el <name> [-m <model>] [-a <agent>] start or status
el <name> <msg>              send a msg
el <name|glob> log [n|all]   view log (default: last 1)
el <name|glob> clear         clear log
el <name|glob> exit          exit session
el exit                      exit all sessions
```
