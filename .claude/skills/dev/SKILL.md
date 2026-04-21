---
name: dev
description: Elixir/OTP development rules for El
---

# RULES

- DO NOT ADD COMMENTS
- Elixir/OTP, leverage GenServers, Supervisors, Ports, distributed Erlang
- Tests with ExUnit
- `mix test` to run, `mix format` to format
- Built on `claude_code` hex package

# CODE RULES

## DDD
- one module per file, filename matches module name
- split following SRP into DDD-named modules
- use domain words, not technical jargon
- names should read like the business, not the framework
- short and clear, never abbreviated, never obfuscated
- abstractions model the domain, not the technology
- names reveal intent, not implementation

## DONT
- NO comments in code, ever. Code should be self-explanatory.

# SPEC RULES

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
- relaxed mocks: use Mox or simple stubs
- shared defaults in setup, set up the happy path
- each test overrides ONLY the one thing that makes that scenario different

## DRY (non-negotiable)
- shared state in setup, returned via context
- never repeat the same setup across tests
- if two tests have identical setup, extract to setup block
- if a state map appears inline in a test, it belongs in setup
- Mimic.copy() calls go in setup, NEVER repeated per test
- stub the happy path in setup, tests override ONLY what differs
- if you see the same line in two tests, you failed DRY

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
