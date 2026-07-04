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
el -v                                 version
el ls                                 list names
el <name> [-json]                     info
el <name> log [n|all] [-json]         view log (default: last 1)

el <name> start [args]                start session
  args:
    -m <model>                        model
    -a <agent>                        agent

el <name> <msg>                       send a msg

el <name|glob> <cmd>                  apply command to one or many
el <cmd>                              apply command to all
  cmds:
    clear                             start new session
    exit                              exit session
    restart                           restart session
```
