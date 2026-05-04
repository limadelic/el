# El `-a` flag investigation — circling log

## Problem
- `cucumber -p dev features/agent.feature:3` (Explicit agent flag) FAILS
- Implicit (`el kent`) and `el lisa` PASS
- Failure: API 400 `"thinking.type.enabled" is not supported for this model`
- Model in env: `ANTHROPIC_MODEL=claude-opus-4-7`
- CC runtime: 2.1.114
- Same agent (kent), same model (claude-opus-4-7), only `-a` path errors

## Theories tried (all wrong or partial)

### T1: -a wiring is broken (kenny's commit lied)
- **Status:** real defect but functionally same opts → not the cause
- cli.ex line 38 used `Start.detect_and_merge_agent(name, agent_opts(agent))` not the new helper
- Net opts identical: `[agent: "kent"]` either way
- ROLLED BACK with `git reset --hard c962bbb`

### T2: Agent model strings wrong (claude-opus-4-7 unknown)
- **Status:** disproved — implicit kent passes with same model
- Earlier we changed `~/.claude/agents/{kent,liz,dude}.md` `claude-opus` → `claude-opus-4-7`
- Made implicit kent respond as Sonnet temporarily
- After revert+experiment, implicit passes again — model is fine

### T3: Cucumber backticks don't propagate env to daemon
- **Status:** disproved — cucumber DOES restart daemon
- `features/support/env.rb:2` runs `system("./el restart")` at boot
- Daemon env confirmed: `ANTHROPIC_MODEL=claude-opus-4-7`, `CLAUDE_CODE_SUBAGENT_MODEL=haiku`
- Env reaches the daemon correctly

### T4: CC 2.1.114 sends thinking.type.enabled for opus-4-7
- **Status:** disproved by user — opus-4-7 works in scenario 2
- If CC always sent bad config, scenario 2 (same model) would also fail
- So the bad request only happens on the -a path

### T5: -a path skips env_model() injection
- **Status:** trivially true but doesn't change opts
- env_model_for(_, agent) returns `[]` when agent set
- Both paths end with same `[agent: "kent"]`

### T6: Session respawn uses wrong opts (kent's last finding)
- **Hypothesis:** `lib/el/session/claude.ex:65` uses `state.opts` not `state.claude_opts`
- session.ex:40 builds `claude_opts` from `rest` (opts minus :resume)
- session.ex:53 first start uses `state.claude_opts` ✓
- claude.ex:65 respawn uses `state.opts` (raw)
- **Why it might bite only -a:** maybe the -a entry stores opts shape where agent: is dropped during rest-extraction... but kent didn't verify this concretely
- **Untested**

## What we know for sure

1. Same agent, same model, same daemon, same env — different result based on path taken in CLI
2. Daemon env is correct
3. Implicit detect just returns the agent NAME string (not file content)
4. Both paths produce `[agent: "kent"]` opts
5. CC is given the agent name; CC reads `~/.claude/agents/kent.md` itself
6. The thinking error MUST come from CC building a request — and CC's behavior depends on what opts el passes per message

## What I haven't actually checked

- Logged CC invocation command line for both paths
- What `state.opts` actually contains in `maybe_respawn_claude` for each path
- Whether the -a path and implicit path enter different code paths in `El.Session.Api.start_link` / GenServer init
- Whether the cucumber feature step `* > el kenny -a kent` triggers daemon respawn between step 1 and step 2 (line 5)
- The `ClaudeCode` hex package's actual handling of `agent:` opt vs no `agent:` opt — does it default-to-loading agent from session name?

## What I keep doing wrong (the circling)

- Speculating on opt shapes without printing them
- Trusting kent's narrative without verifying line refs
- Adding theories without killing prior theories
- Making changes (T1, T2) that introduced more variables instead of just observing

## Next concrete check (read-only)

Add a one-line `IO.inspect(state.opts, label: "respawn opts")` in `maybe_respawn_claude`, rebuild dev release, run both scenarios, compare. Or grep ClaudeCode hex for what `agent:` does when set vs unset.
