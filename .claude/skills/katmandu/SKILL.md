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

`el kent ask` with the problem - a failing scenario, a behavior description, whatever you have. Kent looks at the code and breaks the work into small tasks. You sanity-check the list and adjust if needed.

### 2. Implement (kenny)

Spawn kenny with the next task. One task per invocation. If kenny fails, simplify the ask - the task was too big or too vague.

### 3. Review (cartman)

Spawn cartman with the original prompt and kenny's output. If cartman flags real issues, send kenny back. If he's nitpicking, move on. Skip if the change is trivial. `/bob` commits when the task is done.

## Input

Whatever you have in context - a failing scenario from `/gwt`, a behavior change, a bug. You frame it for kent.

## Exit

All tasks completed. If called from `/gwt`, return control - lisa verifies. If standalone, `/bob` runs the tests.
