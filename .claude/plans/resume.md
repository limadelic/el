# El resume — start here

You are dude. You're picking up an in-flight katmandu loop on `/Users/maykel.suarez/dev/self/el`, branch `wip`. Don't ask for direction. Read this file, then dispatch kenny on the next step.

## Your immediate next action

Dispatch kenny on TODO #39 (SessionMeta facade) with this prompt:

```
TCR step 2 of 7 from kent's restart-persistence breakdown in /Users/maykel.suarez/dev/self/el. Step 1 done at commit `e1bf0f3` (session_meta DETS table opened on app init).

Step: Add `El.SessionMeta` module — thin facade mirroring the `El.MessageStore` pattern. Routes to the `:session_meta` DETS table opened in step 1.

Functions:
- `insert(name, agent, session_id)` — store the meta tuple
- `lookup(name)` — return `{:ok, session_id, agent}` on hit, `{:error, :not_found}` on miss
- `delete(name)` — remove
- `close()` — close the table (called by Application.stop)

Mirror MessageStore's structure exactly. Routes through DetsBackend (which already exists).

Files in scope:
- lib/el/session_meta.ex (new)
- specs/el/session_meta_spec.exs (new)

Out of scope:
- DO NOT touch Session.init yet (step 3)
- DO NOT touch Application.restore_sessions yet (step 4)
- DO NOT touch features/

HARD RULES:
- NO `git commit --amend`. NEW commit.
- NO `git restore`/`checkout`/`stash` on any file. Especially nothing under `features/`.
- NO `git add -A`/`git add .`.
- TDD: failing test first
- code.md §14: pattern match heads, no `case`/`if`/`cond`/`try` in bodies
- specs.md §29: ONE assertion per test
- specs.md §8: mock everything outside the module (use DetsBackend mock if needed)
- Single commit. Message like `Add SessionMeta facade for :session_meta table`
- `mix test` full suite must be green (currently 293/0).

Report: commit SHA, function shapes, test result. Under 100 words.
```

Mark TODO #39 in_progress with owner `kenny-restart-2` before dispatching.

## After kenny lands, run cartman

Send cartman with the standard review prompt:
- Files in scope match (only the two new files)?
- Mirror of MessageStore pattern?
- Pattern-matched heads, no `case`/`if`/`cond`/`try` in bodies?
- ONE assertion per test?
- DetsBackend properly mocked?
- No git amend/restore/checkout/add -A?
- mix test green (≥293/0)?

If cartman flags real violations cite the rule, send kenny back. Don't dismiss without citing the rule he's wrong about.

If clean, mark #39 done, move to step 3 (TODO #35).

## The remaining 5 steps after #39

Run the same kenny → cartman → next-step loop:

- **Step 3 (TODO #35)**: Capture session_id + agent at session birth in `El.Session.init/2`. After `build_state`, extract agent from opts, call `SessionMeta.insert(name, agent, session_id)`. Idempotent on restart.

- **Step 4 (TODO #34)**: Restore meta in `El.Application.restore_sessions/0`. For each session name, call `SessionMeta.lookup(name)`, extract session_id + agent, pass `resume: session_id` and the agent into `el.start(name, opts)`.

- **Step 5 (TODO #40)**: Atomic delete in `El.Lifecycle.do_exit/1`. After `message_store.delete(name)`, also `SessionMeta.delete(name)`. Both cleared on explicit exit.

- **Step 6 (TODO #38)**: Verify meta survives crash. Crash path (Terminator with non-normal reason) already skips delete in Lifecycle. Just verify with a test — no code change.

- **Step 7 (TODO #36)**: Verify `:resume` wired through `Session.Claude`. `resume_options/2` already exists at line ~22 in `lib/el/session/claude.ex`. Verify integration: opts.resume from step 4 reaches Claude on warm restore. Probably no code change.

## After all 7 steps land

Dispatch a haiku to run `bundle exec cucumber -p dev features/restart.feature`. If 🟢, mark TODO #33 (umbrella) done and stop. If red, debug.

## Hard rules — apply to EVERY kenny prompt

- NO `git commit --amend`. NEW commits only.
- NO `git restore`/`checkout`/`stash` on any file. Especially nothing under `features/`.
- NO `git add -A`/`git add .` — stage explicit files only.
- code.md §14: pattern-matched function heads, NO `case`/`if`/`cond`/`try` in function bodies. If a guard needs a non-guard-safe function (like `String.length`), use a dispatch helper that pre-computes the value and pattern-matches on the integer.
- specs.md §29: ONE assertion per test. Compound asserts with `&&` count as multiple. Split via shared `setup` blocks.
- specs.md §8: mock EVERYTHING outside the module via `Application.get_env(:el, :foo, El.Foo)` injection seam.

## Katmandu rules

- NEVER skip kent's breakdown step (it's already done — kent's 7-step plan above)
- NEVER batch tasks, one kenny per task
- NEVER skip cartman, 1 kenny 1 cartman
- NEVER dismiss cartman without citing which rule he's wrong about
- When kenny spirals (2+ cartman bounces on same fix), ask kent for adjudication via `Agent(subagent_type: kent, model: opus)`

## Test infra you'll need

- `verify_docstring` in `features/support/el_helper.rb` strips box chars `│ ─ ╭ ╮ ╰ ╯` AND standalone `…` tokens, word-splits each line, asserts each word appears in actual stdout
- Mocks defined in `specs/test_helper.exs` via `Mox.defmock`, wired via `Application.put_env`: `El.MockFileSystem`, `El.MockSessionApi`, `El.MockEl`, `El.MockStoreModule`, `El.MockAgentDetector`, `El.MockAgentMetadata`, `El.MockClaudeCodeSession`. You'll likely add `El.MockSessionMeta` somewhere in the chain.
- Run cukes: `bundle exec cucumber -p dev` (the `-p dev` profile sets `ENV["DEV"]="1"`, env.rb's `BeforeAll` hook runs `mix release --overwrite` + `./el restart`)

## Cost discipline

The reason this file exists: previous session ran on 1M-token context (5x normal cost). You're now on 200k. Be tight:
- Don't re-read files that are already summarized here
- Don't ask user for status — drive autonomously
- Subagent prompts: keep them tight, copy the structure from above

## Files of interest (in case kenny needs guidance)

- `lib/el/application.ex` — DETS init, `restore_sessions/0`
- `lib/el/message_store.ex` — facade pattern to mirror for SessionMeta
- `lib/el/dets_backend.ex` — low-level DETS wrapper
- `lib/el/session.ex` — session GenServer, init flow
- `lib/el/session/claude.ex` — `resume_options/2` for Claude resume
- `lib/el/lifecycle.ex` — `do_exit/1` for atomic delete

## Card design rules (only relevant if user pulls you back to card work)

- 50-col Unicode box `╭─╮│╰╯`
- Show only known info — null/zero fields hidden
- Two-column header, right column flush right with fixed value width 9 (leading `…` truncation)
- Pairing rule: row 1 = name + `id: …`, row 2 = (agent OR model if no agent) + `cwd: …/self/el`
- ORPHAN RULE: if no second left row exists, drop the cwd row entirely
- `msgs:` row hidden when count is 0
- Response truncated to 2 lines, word-aware wrap at 46 chars

## Now go

Dispatch kenny on TODO #39 using the prompt at the top of this file. Don't ask for confirmation.
