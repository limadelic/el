# TC Ralph

![TC Ralph Sticker](img/tcralph.png)

## Background

### TCR (test && commit || revert)

**Kent Beck** proposed TCR as a stricter form of TDD: after every change, run the tests. If they pass, commit automatically. If they fail, revert to the last passing state. No negotiation, no "I'll fix it in a minute." The constraint forces genuinely small steps — if your change is too big to survive a revert, it was too big.

TCR isn't about testing. It's about **batch size**. The smaller the change, the cheaper the revert, the faster the feedback. It teaches developers to work in increments so small that losing one is trivial.

### The Ralph Loop

**Geoffrey Huntley** applied this to AI agents with the Ralph loop — an autonomous development pattern where each iteration gets a fresh context window, one task, and tests as the success criteria. Progress lives in files and git history, not in the agent's memory.

The name comes from Ralph Wiggum. The pattern is simple: loop forever, feed the same prompt, let tests guide progress. Each iteration starts clean — no context drift, no accumulated confusion. The agent can't get lost because it doesn't remember where it's been.

### Key references

- [Kent Beck: test && commit || revert](https://medium.com/@kentbeck_7670/test-commit-revert-870bbd756864)
- [Geoffrey Huntley: Everything is a Ralph Loop](https://ghuntley.com/loop/)
- [How Practicing TCR Reduces Batch Size](https://www.infoq.com/articles/test-commit-revert/)

## Applying Ralph to Katmandu

Kenny is a Ralph loop. Each invocation: fresh context, one task from kent's breakdown, tests as the gate. Green means `/bob` commits and moves to the next task. Red means revert — oh my god, they killed kenny. Fresh kenny spawns, same task, tries again.

That's the whole point. Kenny dies and comes back. Every time. No baggage, no "I was trying to do X but then I noticed Y." Just one task, one change, one verdict. If he fails, he dies cheap — the change was tiny, nothing of value was lost.

The adversarial layer (cartman) adds what the original Ralph loop doesn't have — a reviewer between test and commit. TCR trusts tests alone. Katmandu trusts tests *and* a critic. Belt and suspenders for agent-generated code.

### mix format as the growth constraint

The TCR gate isn't just tests — `mix format` is embedded in the loop. It enforces consistent style and idiomatic Elixir. Kenny can't generate sloppy code even if he wants to. When a function gets too big, he has to extract. When a module grows unwieldy, he has to split.

The result: code grows by adding small modules, not by inflating existing ones. As a reviewer, you don't need to think hard — the code is already small, clean, and idiomatic. You just check that the modules make sense, the supervision tree is right, and the naming is clear. `mix format` forces the shape; kenny fills it in.
