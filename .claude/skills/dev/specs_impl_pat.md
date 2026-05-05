# Spec Implementation Patterns

Hybrid of Kent Beck's *Implementation Patterns* and Gerard Meszaros' *xUnit Test Patterns*. We adopt Meszaros' vocabulary (Four-Phase Test: Setup / Exercise / Verify / Teardown; test-double taxonomy: Dummy / Stub / Spy / Mock / Fake) and apply it as our implementation patterns for specs.

## Sut

- always the described module under test
- one spec file per module, module name in the describe block
- `describe "ModuleName.function/arity"` groups tests for that function

## Deps

- Deps are always injected via Mox
- define behaviour in lib/el/behaviours.ex, defmock in specs/test_helper.exs
- code we don't own goes through an adapter (own code with a behaviour) + Mox

## Const

- avoid magic values with named bindings
- declare in the test that needs it, or in setup if shared by the whole describe
- module attributes only for true constants (file-wide, immutable)

## Test

- name test describing the intention
- dont leak the implementation

## Steps

- a test has a max of 3 steps: Setup, Exercise & Verify
- also known as Arrange Act Assert, or Given When Then

## Helper

- extract logic helpers — functions that build data — not setup, not data
- used by one spec: define in that spec (private function); used by 2+ specs: extract to specs/support/
- a helper takes args and returns a value; it does not stub, expect, or set context

## Setup

- Setup delays Exercise, minimize it
- stub the happy path in setup, return context
- never copy-paste a setup block, override only what differs (stub for assert-tests, expect for expect-tests)

## Stub

- `stub(MockModule, :function, fn args -> result end)`
- sets a return value without verifying the call (contrast: expect verifies)
- use when the SUT needs a value back but the call itself is not the test's fact

## Mock (Expect)

- `expect(MockModule, :function, fn args -> result end)`
- sets a return value AND verifies the call happened (contrast: stub does not verify)
- use when the call itself is the test's fact (a side effect)
- `verify_on_exit!` in setup makes Mox auto-check

## Exercise

- one Exercise per test
- Exercise calls the SUT, and only the SUT

## Result

- prefer chained assert: `assert Module.function() == expected`
- capture when asserting on a derived property: `result = Module.function(); assert derive(result) == expected`

## Verify

- a test verifies one fact: either a return value (`assert`) or a side effect (`expect`). Not both.
- the assert/expect proves the intention of the test name

## Teardown

- Teardown is automatic — `verify_on_exit!` runs at process exit
- prefer Mox auto-verification over manual on_exit callbacks
