# Spec Rules

## Philosophy
- Growing Object Oriented System Guided By Test
- London School of TDD

## What gets mocked 
- Code we own: every collaborator gets a behaviour and a Mox mock
- Code we don't own: wrap + mock only when it breaks Feathers' rules (FS, network, DB, clock, processes outside the unit). Otherwise call directly.

## Mock Style
- use Mox with behaviours (lib/el/behaviours.ex)
- Mox.defmock in specs/test_helper.exs, one mock per behaviour
- import Mox + setup :verify_on_exit! in each spec
- stub the happy path in setup, expect in tests
- each test overrides ONLY the one thing that makes that scenario different
- code we don't own that breaks Feathers gets wrapped in our own adapter (own code with a behaviour)
- adapters are tested through the layer above, not directly
- 10ms timeout per test — if it's slower, it's not a unit test

## DRY
- shared state in setup, returned via context
- never repeat anything across tests
- same line in two tests = failed DRY

## Assertions
- ONE assertion per test
- if you need multiple asserts, split into multiple tests
- the test name describes the one thing being asserted

## Structure
- specs/ mirrors lib/: one spec file per module
- files named `_spec.exs` not `_test.exs`

## What to test
- test observable behavior: what the function returns, what side effects it produces (via mock verification)
- never test: caching, memoization, property assignment, language mechanics
