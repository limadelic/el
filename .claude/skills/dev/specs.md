# Spec Rules

## Philosophy
- ONLY unit tests, NEVER integration tests
- NEVER start real processes (no start_link, no GenServer.start, no Application.ensure_all_started)
- mock the next module: each spec tests ONE module
- mock EVERYTHING that's not in this module
- whatever is external gets mocked, whatever is internal gets tested
- GenServer callbacks (init, handle_cast, handle_call, handle_info) are functions, test them directly
- no end-to-end through the whole stack
- no Process.sleep, ever

## Mock Style
- use Mox with behaviours (lib/el/behaviours.ex)
- Mox.defmock in specs/test_helper.exs, one mock per behaviour
- import Mox + setup :verify_on_exit! in each spec
- stub the happy path in setup, expect in tests
- each test overrides ONLY the one thing that makes that scenario different
- for modules without behaviours, use simple stub modules via Application.get_env
- Erlang wrappers (:dets) are tested through the layer above, not directly
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
