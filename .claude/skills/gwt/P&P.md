# Patterns & Practices

## Goal

- Maximize reuse of existing DSL
- Minimize new step definitions
- Cabbage compiles `.feature` files to ExUnit tests

## The DSL

### Start a named session
```gherkin
Given I start session "dude"
```

### Tell a session (fire and wait)
```gherkin
When I tell "dude" "hey man"
Then the response contains "hey"
```

### Ask a session (query and verify)
```gherkin
When I ask "ita" "1 + 1"
Then the response is "2"
```

### List sessions
```gherkin
When I list sessions
Then I see "dude" running
And I see "ita" running
```

### Session not found
```gherkin
When I tell "nobody" "hello"
Then I get error "session \"nobody\" not found"
```

### Execute a shell command
```gherkin
Given I run "el start alice"
```

### Negative assertion
```gherkin
Then the response does not contain "error"
```

## Scenarios

- Declarative — WHAT not HOW
- One outcome per scenario
- Use domain language (session, tell, ask, start)
- No incidental detail

## File Organization

```
test/features/
  <domain>/
    <feature>.feature
```

## Scope

- Features test user-facing behavior (the WHAT)
- Implementation edge cases belong in ExUnit tests (the HOW)
- Ask: "would a user describe this scenario?" If no, it's a unit test

## Anti-Patterns

- Creating new step definitions when the DSL covers it
- Imperative scenarios with implementation details
- Testing multiple outcomes in one scenario
- Testing OTP internals — features test the CLI surface
