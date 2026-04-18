# Katmandu

![Katmandu Sticker](img/sticker.png)

## Background

The name comes from the flow: kenny, cartman, dude. Katmandu.

The core idea is **small steps**. When you break implementation into tiny tasks, each change has a small delta — less room for mistakes, easier to review, easier to roll back. This is straight from Kent Beck's playbook.

**Kent Beck** advocates that the ability to take small steps is what manages difficulty. Large steps create compounding risk — too many things change at once, and when something breaks you don't know why. Small steps let you adjust course incrementally: "a little this way, a little that way."

His **Tidy First?** philosophy takes this further — work as a series of small structural and behavioral changes. Tidyings are "cute, fuzzy little refactorings that nobody could possibly hate on" — guard clauses, helper extractions, reordering. The insight: you can always make big changes in small, safe steps. Structure first, then behavior.

The loop is also guided by tests from the outside in — the **GOOS** approach (Growing Object-Oriented Software, Guided by Tests) by **Nat Pryce** and **Steve Freeman**. A failing acceptance scenario defines the outer boundary. Implementation works inward: the scenario forces a module, that module calls another, and so on down the layers. Tests at each layer drive the design of the layer beneath.

### Key references

- [Kent Beck: Tidy First?](https://www.oreilly.com/library/view/tidy-first/9781098151232/)
- [Kent Beck: Canon TDD](https://tidyfirst.substack.com/p/canon-tdd)
- [Freeman & Pryce: Growing Object-Oriented Software, Guided by Tests](http://www.growing-object-oriented-software.com/)
- [Kent Beck on small steps and managing difficulty](https://pierodibello.medium.com/my-notes-on-kent-becks-tdd-course-8a1a7c8b7a95)

## Applying Katmandu to AI Agents

Developers have always known they should work in small steps. Beck has been saying it for decades. But humans don't — under pressure, discipline breaks down. We skip the refactor, we batch changes, we say "I'll clean it up later." The process was right; the discipline was impossible to sustain.

Agents don't cut corners. They don't get tired or impatient. The katmandu loop bakes the discipline into the process itself:

- **Kent analyzes without coding** — pure decomposition, no temptation to just start hacking
- **Kenny implements without judging** — one task, fresh context, small delta. Can't drift because each invocation is scoped to a single change
- **Cartman critiques without having written it** — an LLM can't generate and verify in the same pass. Splitting the roles gives genuine adversarial review

Same model, different cognitive tasks. The loop enforces what Beck preached but humans could never sustain — consistent small steps, every time, no exceptions.

## How It Fits

Katmandu is the innermost ring of DDD (Dude-Driven Development):

1. **Three Amigos** (`/3-amigos`) — discover WHAT: examples, rules, questions
2. **GWT** (`/gwt`) — write acceptance scenarios from those examples
3. **Katmandu** (`/katmandu`) — implement code in small steps to make scenarios pass

GWT hands katmandu a failing scenario. Kent breaks it down. Kenny implements each piece. When all tasks are done, control returns to GWT for verification.

## The Ralph Loop

Kenny's inner engine is the TC Ralph loop — see [tcralph.md](tcralph.md) for the full background on TCR, the Ralph loop, and how katmandu uses it.

## The Cast

### kent

- Named after [Kent Beck](https://www.kentbeck.com) — XP, TDD, Tidy First, simplicity
- Analyzes the problem, looks at the code, breaks it into small tasks
- Ephemeral — spawned once at the start, dies after delivering the task list
- Channels Tidy First: small safe changes, structure before behavior

### kenny

- The implementer — takes one task, writes the code, done
- Ephemeral — fresh context per task, keeps changes small and focused
- Knows the codebase and conventions — tell him WHAT, not HOW

### cartman

- The adversarial reviewer — same knowledge as kenny, different job
- Ephemeral — fresh eyes every review
- Catches what kenny can't see about his own output
- On haiku — cheap, fast, disposable
