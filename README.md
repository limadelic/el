# El

CLI for managing headless Claude Code sessions (zombies).

Start a Claude session in the background, send it messages, get responses, view logs, kill when done.

## Install

**Homebrew** (recommended):
```bash
brew install limadelic/tap/el
```

**Elixir devs**:
```bash
mix escript.install hex el
```

## Usage

Start a zombie session:
```bash
el dude
```

Send a message and wait for response:
```bash
el dude ask "What is 2+2?"
```

Send a message without waiting:
```bash
el dude tell "Background task: analyze this dataset"
```

View all messages:
```bash
el dude log
```

List all sessions:
```bash
el ls
```

Kill a session:
```bash
el dude kill
```

Kill all sessions:
```bash
el kill all
```

## How It Works

`el <name>` starts a Claude Code session that self-daemonizes:
- Binary spawns El.Supervisor (if not running)
- Creates El.Session for the named session
- Exits immediately, returning control to shell (no blocking, no `&`, no backgrounding)
- Session persists as an Erlang process
- Subsequent commands discover and reuse the active session

Built on the Erlang/OTP supervision model. Sessions crash, they restart. It just works.

## Why

Multi-agent Claude workflows need reliable inter-process messaging. El solves it with the simplest possible interface: one process, one CLI.
