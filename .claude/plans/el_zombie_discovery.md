# El Zombie — Discovery Plan

## Story (Yellow)

El zombie — first release. Start named headless Claude sessions from the shell, message them from another shell.

```
$ el dude              # start a named session
$ el elita             # start another
$ el dude tell hey man   # fire-and-forget, returns immediately
$ el elita ask 1 + 1     # wait for response, get "2"
```

## Rules (Blue)

1. **One BEAM, many sessions.** All headless sessions live in a single BEAM process. DynamicSupervisor + Registry. `el dude` adds a child.
2. **Tell is fire-and-forget, ask blocks.** `tell` sends a message and returns immediately (no response printed). `ask` waits for Claude's response and returns text. Tell Don't Ask principle.
3. **Sessions are named.** `el <name>` registers a named GenServer via Registry. `el <name> tell msg` routes to it.
4. **Built on claude_code hex.** ClaudeCode.Session wraps Claude CLI as GenServers with NDJSON streaming. We wrap that, not reinvent it.
5. **Headless only.** No TUI, no PTY. Pure stdin/stdout NDJSON. PTY mode already exists separately.
6. **Zombie by default.** `el dude` starts headless (zombie). Shell mode comes later behind a `--shell` flag. No TTY detection needed.

## Examples (Green)

### Happy path — start and tell
```
# Terminal 1: start the El BEAM
$ el

# Terminal 2: start sessions and message them
$ el dude
$ el elita
$ el dude tell hey man
$ el elita ask 1 + 1
> 2
```

### Multiple sessions coexist
```
$ el dude
$ el elita
$ el ls
> dude  running
> elita    running
$ el dude tell summarize this file
$ el elita tell review this PR
```

### Session not found
```
$ el nobody tell hello
> error: session "nobody" not found. Run `el nobody` first.
```

### Session lifecycle
```
$ el dude
$ el dude log
> [conversation history]
$ el dude kill
$ el ls
> no sessions running
```

## Questions (Red) — Parked for Later

1. **Resume on restart.** If a session crashes and restarts, conversation history is lost. ClaudeCode has a `:resume` option but El would need to persist session_ids. Parked for v2.
2. **Auto-restart vs manual.** Should crashed sessions auto-restart (OTP supervisor) or stay down? Parked — start without auto-restart, add later.
3. **True fire-and-forget.** Tell IS fire-and-forget (GenServer.cast). Ask blocks and returns text (GenServer.call). Done.
4. **Permission mode.** Sessions inherit Claude CLI permission mode. No El-level enforcement yet. Parked.
5. **Install story.** Escript? Burrito? Homebrew? Users need Elixir installed for now. Parked.

## CRC Cards

| Object | Responsibilities | Collaborators |
|--------|-----------------|---------------|
| El | Public API: start/1, tell/2, ask/2, log/1, kill/1, ls/0 | El.SessionSupervisor, Registry |
| El.SessionSupervisor | DynamicSupervisor for named sessions | ClaudeCode.Session |
| El.CLI | Parse shell commands, route to El API | El |
| ClaudeCode.Session | Wrap Claude CLI process, stream NDJSON | Claude CLI (external) |
| Registry | Named process lookup for sessions | Erlang Registry |

## Architecture

```
El.Application
├── Registry (named session lookup)
└── El.SessionSupervisor (DynamicSupervisor)
    ├── ClaudeCode.Session (:dude)
    ├── ClaudeCode.Session (:elita)
    └── ...
```

## Scope

- ~150 lines of Elixir
- Wire DynamicSupervisor + Registry into El.Application
- El.start/1, El.tell/2, El.ask/2, El.log/1, El.kill/1, El.ls/0
- CLI commands: `el <name>`, `el <name> tell msg`, `el <name> ask msg`, `el <name> log`, `el <name> kill`, `el ls`

---

## Progress (as of 2026-04-18)

### Setup Complete

**Skills & Agents copied from ~/dude/code and adapted for El:**

Agents (5):
- `dude.md` — El Dude, domain expert. Three layers (El/Dude/CC).
- `liz.md` — Deliberate Discovery. Liz Keogh style.
- `kent.md` — XP/TDD. Kent Beck style. Feasibility.
- `lisa.md` — Acceptance tests. Lisa Crispin style. Writes .feature files with Cucumber.
- `eric.md` — Domain reviewer. Eric Evans style. Adversarial critic.
- `bob.md` — Build agent. mix test, mix format, git. No coding.

Skills (6):
- `3-amigos/` — Discovery phase. liz + kent + dude.
- `gwt/` — GWT (Given-When-Then). Acceptance scenarios with Cucumber (Ruby). lisa + eric.
- `ddd/` — Dude-Driven Development. Glossary, three layers, the loop.
- `dev/` — Elixir/OTP dev rules.
- `sup/` — Team supervision. In-process mode (no tmux needed).

Config:
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` set in ~/.zshrc
- `HEX_UNSAFE_HTTPS=1` set in ~/.zshrc (corporate TLS bypass)
- Cucumber + RSpec added to Gemfile (test only)
- `mix test` passing (green)

### 3 Amigos Discovery — DONE

Ran the 3 amigos session. Key decisions:
- One BEAM, DynamicSupervisor + Registry
- Tell and ask both block, return text (semantic difference only)
- Resume/auto-restart parked for later
- ~150 lines of Elixir, mostly wiring existing claude_code hex

### Next Step — GWT

GWT — acceptance scenarios DONE (zombie.feature with Cucumber/Ruby)

### Existing Code

```elixir
# lib/el.ex
defmodule El do
  def start(name) when is_atom(name) do
    {:ok, _pid} = ClaudeCode.start_link(name: name)
    name
  end

  def tell(name, message) do
    name
    |> ClaudeCode.stream(message)
    |> ClaudeCode.Stream.text_content()
    |> Enum.join()
  end
end
```

Missing: El.ask/2, El.log/1, El.kill/1, El.ls/0, DynamicSupervisor, Registry, CLI commands.
