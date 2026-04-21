---
name: dev
description: Elixir/OTP development rules for El
---

# RULES

- DO NOT ADD COMMENTS
- Elixir/OTP — leverage GenServers, Supervisors, Ports, distributed Erlang
- Tests with ExUnit
- `mix test` to run, `mix format` to format
- Built on `claude_code` hex package

# CODE RULES

## DDD
- one module per file, filename matches module name
- split following SRP into DDD-named modules
- use domain words, not technical jargon
- names should read like the business, not the framework
- short and clear — never abbreviated, never obfuscated
- abstractions model the domain, not the technology
- names reveal intent, not implementation

## DONT
- NO comments in code — ever. Code should be self-explanatory.

# SPEC RULES

## Philosophy
- mock the next module — each spec tests ONE module
- mock stdlib (File, System, Port) for I/O modules
- no end-to-end through the whole stack

## Mock Style
- relaxed mocks: use Mox or simple stubs
- shared defaults in setup — set up the happy path
- each test overrides ONLY the one thing that makes that scenario different

## Structure
- specs/ mirrors lib/ — one spec file per module
- files named `_spec.exs` not `_test.exs`

## What to test (BDD)
- test what the caller sees, not how the code works inside
- if you can't observe it from outside the module, don't spec it
- never test: caching, memoization, property assignment, language mechanics
