# Spec Implementation Patterns

## Sut

- always the described module under test
- one spec file per module, module name in the describe block
- `describe "ModuleName.function/arity"` groups tests for that function

## Deps

- Deps are always injected via Mox or Application.get_env
- Mox: define behaviour in lib/el/behaviours.ex, defmock in test_helper.exs
- Application.get_env: define stub module in test_helper.exs, inject via Application.put_env

## Const

- avoid magic values with named bindings
- use module attributes or setup context for shared constants
- declare in setup: `%{name: :dude, message: "hello"}`

## Test

- name test describing the intention
- dont leak the implementation

## Steps

- a test has a max of 3 steps: Setup, Exercise & Verify
- also known as Arrange Act Assert, or Given When Then

## Helper

- extract repeated patterns into setup blocks
- keep tests DRY by extracting into shared setup

## Setup

- Setup delays Exercise, minimize it
- stub the happy path in setup, return context
- keep Setup that helps explain the test
- hide Setup that must exist but is tmi (put in test_helper.exs)
- never copy-paste a setup block, override only what differs via expect

## Stub

- stubs belong in Setup (setup block)
- `stub(MockModule, :function, fn args -> result end)`
- use them when a call must return something needed
- stubs set up the happy path, expects override for specific scenarios

## Mock (Expect)

- expects belong in the test, next to exercise
- `expect(MockModule, :function, fn args -> result end)`
- they express something was called (side effects, sagas)
- Mox auto-verifies via setup :verify_on_exit!

## Exercise

- there can only be one Exercise per test
- Exercise calls the function under test on the Sut module
- never exercise a mock

## Result

- prefer assert chained to Exercise: `assert Module.function() == expected`
- otherwise capture: `result = Module.function()`

## Verify

- ideally a single assert per test
- it should prove the intention of the test name
- expect verifies side effects, assert verifies return values

## Teardown

- keep Teardown invisible
- use on_exit callbacks in setup when needed
- prefer Mox verify_on_exit over manual teardown
