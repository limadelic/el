---
name: belize
description: El acceptance testing DSL and rules
---

# Belize (El)

- Read global belize for the process and cast
- This skill defines El's DSL and rules

## DSL

- One operator: `>` — everything is a shell command
- Gherkin keyword `*` keeps it neutral

### Start a session (zombie)
```gherkin
* > el dude
```

### Tell (fire-and-forget)
```gherkin
* > el dude tell hey man
```

### Ask (query-and-answer)
```gherkin
* > el dude ask 1 + 1
  | 2 |
```

### Log (inspect received messages)
```gherkin
* > el dude log
  | hey man |
```

### List sessions
```gherkin
* > el ls
  | dude  |
  | elita |
```

### Kill a session
```gherkin
* > el dude kill
```

### Absence assertion
```gherkin
* > el ls
  | (dude) |
```

- `(name)` in a table means name should NOT be present

## Tables

- Tables verify command output
- No column headers until needed
- One step handles `>` with or without tables
- `el <name>` self-daemonizes, returns to shell immediately

## Scenarios

- Declarative, WHAT not HOW
- One outcome per scenario
- Domain language: el, dude, elita, tell, ask, log, kill, ls
- No incidental detail
- Happy path first, edge cases later

## File Organization

```
features/
  <feature>.feature
  step_definitions/
    el_steps.rb
  support/
    env.rb
    hooks.rb
```

## Scope

- Features test user-facing behavior (the WHAT)
- Implementation edge cases belong in ExUnit tests (the HOW)
- Ask: "would a user describe this scenario?" If no, it's a unit test

## Anti-Patterns

- Creating new step definitions when `>` covers it
- Imperative scenarios (implementation details)
- Testing multiple outcomes in one scenario
- Testing OTP internals, features test the CLI surface
