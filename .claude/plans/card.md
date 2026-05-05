# El agent card

## Goal

`el <name>` always prints a card — the session at a glance. Ping verifies the agent loaded; ping naturally becomes the first log entry.

## Behavior

### Default ping (when no message given)

- **agent set** → `"who are you?"`
- **no agent** → `"the dude abides"` (boots the session into rules-following mode)

Later: per-user configurable. For now hardcoded.

### `el <name>` (no message)

- **non-existing + agent** → start, silent ping `"who are you?"`, log as msg #1, print card
- **non-existing + no agent** → start, silent ping `"the dude abides"`, log as msg #1, print card
- **existing** → no restart, no ping, print card from cached state

### `el <name> <words...>` (message provided)

- **non-existing** → start session, use `<words>` as the ping (replaces default), log as msg #1, print card. Same regardless of agent.
- **existing** → send `<words>` as next message (current `:msg` behavior), append to log, print card

## Card content

The card = header fields at the top + the log below. Not a separate object — it's the layout.

```
name:    kenny
agent:   kent
model:   claude-opus-4-7
msgs:    1
─────────────────────────
> who are you?
I'm dude — Kent Beck flavored. I abide.
```

- `agent` always shown when set (provenance is implicit: name == agent → detected; name != agent → explicit `-a`)
- `agent`/`model` lines omitted when no agent at all
- log section shows the last entry, **truncated** (prompt + reply both shortened). May reuse the `log` function under the hood for the data, but renders its own truncated form

## Implementation seams

- **`El.CLI.execute(:start, [name])`** → after `handle_find_daemon_for_start`, if agent in opts, call `el().ask(name_atom, "who are you?")` (silent — discard return), then `print_card(name)`.
- **`El.CLI.execute(:msg, [name, word | more])`** → after `execute_msg` (which already auto-starts), `print_card(name)`. The ping becomes the user's words.
- **`El.Session.Claude.stream_to_result/2`** → already collects events. Capture Init metadata and stash on session state (new field `init_meta`).
- **`El.Session.API.card/1`** → new GenServer call returning `%{name, agent, model, msgs, last}`.
- **`El.CLI.Output.format_card/1`** → render the map as the block above.

## Cucumber

```
Feature: Agent card

  @el_kent
  Scenario: Card on start with agent
    * > el kent:
      | name:  kent           |
      | agent: kent           |
      | model: opus           |
      | msgs:  1              |

  Scenario: Card with custom ping
    * > el kent "tell me your style":
      | name:  kent           |
      | agent: kent           |
      | model: opus           |
      | msgs:  1              |
      | last:  simplicity     |
    * > el kent exit

  Scenario: Card without agent
    * > el randomname:
      | name: randomname |
      | msgs: 0          |
    * > el randomname exit
```

## Persistence

State that **must survive daemon restart** (only dies on `el <name> exit`):
- log (messages)
- Init metadata (model, agent, session_id, etc.)
- session_id (already used for `:resume`)

If logs currently die on restart, that's a bug to fix as part of this story. `MessageStore` + `DetsBackend` already exist — wire Init metadata into the same persistence path. Card becomes a pure read of persisted state on restart, no re-ping needed.

## Open questions

- **Card on existing-session call** — do we re-print card every time, even when sending a message? (Current plan: yes, card always prints after any `el <name>` call.)
- **`last` length** — single line truncated to ~80 chars?
- **Cached card vs fresh** — for existing sessions, we read from state. State updates on every message via `stream_to_result`. So always fresh.
- **Ping cost** — every new session pays for one round-trip. Acceptable.
- **Self-test failure** — if Init.model doesn't match agent.md's `model:` field, do we warn? (Bonus.)
