---
name: katmandu
description: The dev loop - kent analyzes, kenny codes, cartman reviews
---

# Katmandu

## The Cast

Kent is persistent via `el kent`. Kenny and cartman are ephemeral haiku subagents.

| Name    | How              | Model  | Role                                         |
|---------|------------------|--------|----------------------------------------------|
| kent    | `el kent`        | opus   | analyzes the problem, breaks it into tasks    |
| kenny   | Agent(kenny)     | haiku  | implements one task at a time                 |
| cartman | Agent(cartman)   | haiku  | reviews kenny's output                        |

## Tasks

Kent's breakdown becomes the task list. Create one task per item kent identifies (all `pending`). Mark each `in_progress` when kenny starts it, `completed` when done.

## The Loop

### 1. Analyze (kent)

`el kent <msg>` with the problem - a failing scenario, a behavior description, whatever you have. Kent looks at the code and breaks the work into small tasks. You sanity-check the list and adjust if needed.

### 2. Implement (kenny)

Spawn kenny with the next task. One task per invocation. Kenny does TCR — test && commit || revert. If tests pass, he commits. If they fail, he dies cheap and respawns fresh.

### 3. Review (cartman)

Spawn cartman with the original prompt and kenny's output. If cartman flags real issues, send kenny back (fresh spawn, same task). If he's nitpicking, move on.

## Input

Whatever you have in context - a failing scenario from `/gwt`, a behavior change, a bug. You frame it for kent.

## Exit

All tasks completed. If called from `/gwt`, return control - lisa verifies. If standalone, `/bob` runs the tests.
