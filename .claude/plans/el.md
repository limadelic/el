# El

*The telepathic bridge between Claude processes. Seed of Elita. El Dude abides.*

## Problem

Claude Code agent teams messaging is broken. SendMessage writes to JSON inbox files, but the polling/receiving side fails across every backend (tmux, iTerm2, in-process, VS Code). Nobody in the wild has it working reliably as a daily workflow.

## Insight

The problem is RECEIVING, not sending. Claude Code has no reliable incoming port for real-time messages. The inbox poller (`useInboxPoller.ts`) polls every 1 second and frequently drops messages.

## Discovery

Kent reviewed Claude Code source and found these injection points:

| Port | Latency | Available | Constraint |
|------|---------|-----------|------------|
| stdin NDJSON | zero | YES | Must own the process |
| Inbox JSON files | 1s poll | YES | Unreliable polling |
| UDS inbox | zero | NO | `UDS_INBOX` feature flag |
| MCP channels | zero | NO | Anthropic-gated (OAuth, org policy) |
| REPL bridge | zero | NO | GrowthBook flag, Claude.ai subscription |

**stdin is the only reliable, ungated, zero-latency port.** But you must own the Claude process to use it.

## The stdin Protocol

```json
{"type":"user","message":{"role":"user","content":"hello"},"parent_tool_use_id":null}
```

- One line of NDJSON per message
- Launch with: `claude -p --input-format=stream-json --output-format=stream-json`
- Mid-conversation injection works — stdin is never paused
- Control subtypes: `interrupt`, `initialize`, `set_permission_mode`
- Structured NDJSON responses on stdout

## Architecture

Two modes, one system:

### Headless Mode (priority)
- `claude_code` hex package wraps Claude CLI as GenServers
- `ClaudeCode.start_link(name: :dude)` → named session
- `ClaudeCode.stream(:dude, "do this")` → structured responses
- Multiple sessions in one BEAM, zero shared state
- Distributed sessions via Erlang distribution

### PTY Mode (proven, polish later)
- `script -q /dev/null` allocates a PTY for full TUI
- Read/write via `/dev/tty` bypasses Erlang's prim_tty
- `el.sh` wrapper sets `stty raw -echo`, traps cleanup
- User types normally, sees full Claude Code UI
- `El.PTY.inject/2` pushes messages from other sessions

### Cross-node messaging
- Each session starts as a distributed BEAM node (`--sname`)
- `el <name> tell msg` connects and injects via GenServer cast
- Same mechanism for headless and PTY sessions

## What This Is NOT

- NOT Elita — Elita is the full agentic platform (agents as md files → GenServers)
- NOT a patch on Claude Code teams — we're replacing teams entirely
- NOT an MCP server — we own the process, not a plugin

## What This IS

- A reliable phone system for multiple Claude processes
- An Elixir app that wraps Claude CLI via Ports
- A bridge that makes multi-agent workflows work TODAY
- A stepping stone — patterns learned here feed into Cucumber (Ruby) later

## Research Sources

- Kent's source review: `~/.claude/plans/kent-inbox.md`
- Arana's web research: `~/.claude/plans/arana-inbox.md`
- Key files in CC source:
  - `tools/SendMessageTool/SendMessageTool.ts`
  - `utils/teammateMailbox.ts`
  - `hooks/useInboxPoller.ts`
  - `utils/messageQueueManager.ts`
  - `services/mcp/channelNotification.ts`

## Prior Art

- OpenAI Symphony — 96.1% Elixir agent orchestration
- `claude_code` Elixir SDK on Hex — sessions as GenServers
- Sagents — Elixir agents with OTP supervision + LiveView
- Synapse — declarative multi-agent framework with signal bus
- GNAP — git-native agent protocol, 4 JSON files

## PTY Libraries (for hardening)

- **ExPTY** v0.2.1 — full PTY allocation, based on Microsoft's node-pty
- **erlexec** v2.2.4 — mature Erlang process manager with PTY
- **net_runner** v1.2.0 — modern, PTY + cgroup isolation

## Project

- Location: `~/dev/self/el/`
- Repo: `limadelic/el`
- Sibling of: `~/dev/self/elita/`
- Dep: `claude_code` from hex.pm
- Reference: `~/dev/ext/claude_code_ex/` (cloned source)

## Answered Questions

- Name: **El** (not plug, not phone — just El)
- Registry: Elixir's built-in Registry, no custom needed
- Agent discovery: Named sessions, `GenServer.call(:name, ...)`
- `claude -p`: Yes, supports tools, edits, everything
- User interaction: Talk to one Claude (dude), dude delegates to others via El
- TUI: PTY via `script` works, ExPTY for production
- Status line: JSON via stdin to `dude status_line`, El can provide same data
- Auth: Works with API keys, Pro plans, Bedrock, Vertex, proxies — El is agnostic
- Yolo loop: El can replace it (supervision) or coexist alongside it
- CLI commands: `el <name>`, `el <name> kill`, `el <name> tell`, `el <name> ask`, `el <name> log`, `el ls`

## Status

### PROVEN
- Headless sessions: start, send, receive via `claude_code` hex ✓
- PTY TUI: full Claude Code UI through Elixir-managed process ✓
- Cross-node messaging: `el <name> tell` injects messages via distributed Erlang ✓
- Two sessions talking: dude/elita/man all reachable ✓

### NEXT — Headless Multi-Agent
1. Supervision tree for headless sessions
2. `El.tell/2` and `El.ask/2` — fire-and-forget vs wait-for-response
3. Session registry — who's running, what are they doing
4. Integration with dude workflow — skills, tell skill, etc.
5. Multiple sessions in one BEAM (vs separate nodes)

### LATER — Shell & Polish
1. ExPTY instead of `script` hack
2. Signal handling (Ctrl+C, resize)
3. Yolo loop integration
4. Clean terminal on crash
5. Lighter `tell` mechanism (Unix socket vs spawning BEAM)
