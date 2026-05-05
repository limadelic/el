# el dev/prod separation + fast unit tests

## Goals

1. Run dev code (`./el`) and prod code (`el`) on the same machine, isolated
2. All unit tests green at 10ms timeout, no exceptions

## Dev/prod fix

Three changes keyed off `DEV=1` env var:
1. `cli.ex:269` daemon_node returns el_dev@127.0.0.1 when DEV - DONE
2. `application.ex` DETS path uses ~/.el/dev/ when DEV - PENDING
3. `application.ex` mkdir_p! the right dir - PENDING

## Fast unit tests

Mimic uses GenServer calls (10-100ms each). 146 calls across 9 spec files. Impossible to hit 10ms with Mimic. Remove Mimic, use function parameter injection (Jose Valim pattern).

### Pattern

Production: add opts param with defaults
```elixir
def start(name, opts \\ []) do
  registry = opts[:registry] || Registry
  registry.lookup(El.Registry, name)
end
```

Test: pass mock modules, zero overhead
```elixir
defmodule MockRegistry do
  def lookup(El.Registry, :dude), do: []
end

test "starts session" do
  El.start(:dude, registry: MockRegistry)
end
```

### Spec files to refactor (one task each)

| File | Mimic calls | Mocked modules |
|------|-------------|----------------|
| application_spec.exs | 5 | El.MessageStore |
| claude_code_spec.exs | 11 | ClaudeCode.Session |
| el2el_spec.exs | 10 | El.Session |
| message_store_spec.exs | 2 | El.DetsBackend |
| pty_spec.exs | 21 | Port, File |
| session_spec.exs | 27 | El.MessageStore, Task |
| el_spec.exs | 25 | Registry, DynamicSupervisor, El.Session, El.Application |
| cli_spec.exs | 31 | El, IO, System |
| on_off_spec.exs | 14 | Registry, DynamicSupervisor, El.Session, El.ProcessMonitor |

### Also

- test_helper.exs: remove all Mimic.copy calls
- mix.exs: remove mimic dependency
- ExUnit timeout: 10ms

## Status

daemon_node done. Mimic removal scoped. Ready to execute.
