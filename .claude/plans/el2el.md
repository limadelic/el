# El2El: Inter-Session Messaging

Issues: UKGEPIC/dude#178 (@dude), UKGEPIC/dude#179 (dogfood burrito with amigos)

## Story (Yellow)

El sessions talk to each other via the actor model — Claude decides when and who to talk to, el delivers the messages. No orchestrator. Every el is equal.

## Architecture

- **Shell-to-El**: human tells or asks a session. Tell = fire-and-forget. Ask = block for response.
- **El-to-El**: always tell. Actor model. Fire-and-forget, return address via `[from name]`.
- **Claude is the brain**: messages always go to Claude first. Claude decides to route by emitting `@el_name` in its output.
- **El is the hands**: el intercepts Claude's output stream, detects `@el_name` patterns, delivers as tells to target sessions.
- **No orchestrator**: a coordinator is just another el with a job, not a special architecture.

## Rules (Blue)

1. **`@el_name` is the routing token** — Claude emits `@el_donnie message` in its output when it decides to talk to another session. `~r/@el_(\w+)\s+(.*)/`.
2. **Claude-only detection** — el parses Claude's output stream for the token. Human input always goes to Claude first; Claude decides to route.
3. **El-to-el is always tell** — actor model. No asks between sessions. The receiver decides independently whether and how to respond by sending a new message back.
4. **Stream interception** — el watches Claude's streamed output. When `@el_name` is detected, el extracts the target and payload, delivers via `El.tell/2`.
5. **Self-route filtered** — `if target != state.name`.
6. **Target not running -> error** — no silent drops. `"donnie is not running"`.
7. **Return address** — messages carry sender identity: `[from dude] payload`. The receiver knows where to reply.
8. **Message buffering** — tells that arrive while Claude is busy accumulate in GenServer state. When Claude finishes, buffered tells coalesce into one prompt. One batch, one Claude turn.
9. **Asks never coalesce** — asks always get their own dedicated Claude turn. Tells batch, asks stand alone.
10. **Claude is single-threaded** — one prompt at a time via the port session. GenServer is concurrent, Claude is sequential. Messages queue, not tasks.
11. **Log: 4-element tuple** — `{type, msg, response, %{from: name}}`. Types: tell, ask, relay.
12. **Full output stays in log** — nothing stripped. Routes extracted and relayed as side-effects.

## Removed

- `detect_routes/1` on human input — Claude decides, not regex
- `tell_ask` and `ask_tell` compound commands — Claude picks the verb
- Pure relay / postman model — Claude always processes the message first
- Task-per-tell spawning — buffer instead, one task at a time

## Examples (Green)

### Claude-directed tell
```
Given dude and donnie sessions are running
When el dude tell "tell donnie he is out of his element"
Then dude's Claude processes the message
And Claude's output includes: @el_donnie you are out of your element
And el intercepts, delivers to donnie as a tell
And donnie receives [from dude] you are out of your element
And donnie's Claude processes it independently
```

### Response back (actor model round-trip)
```
Given dude and donnie sessions are running
When donnie receives [from dude] you are out of your element
And donnie's Claude decides to respond
And Claude's output includes: @el_dude I am the walrus
Then el intercepts, delivers to dude as a tell
And dude receives [from donnie] I am the walrus
```

### Multi-route in one response
```
Given alice, donnie, and walter sessions are running
When alice's Claude responds with:
  I'll handle migration.
  @el_donnie handle auth middleware
  @el_walter update the test suite
Then donnie receives [from alice] handle auth middleware
And walter receives [from alice] update the test suite
And alice's full response stays in alice's log
```

### Target not running
```
Given only dude session is running
When dude's Claude outputs @el_donnie you are out of your element
Then relay fails, error logged: "donnie is not running"
```

### Message coalescing
```
Given dude session is running and Claude is busy processing
When three tells arrive:
  1. [from donnie] tests passed
  2. [from walter] PR is ready
  3. [shell] check the status
Then all three buffer in GenServer state
When Claude finishes current work
Then dude's Claude receives one coalesced prompt:
  "You have 3 new messages:
   1. [from donnie] tests passed
   2. [from walter] PR is ready
   3. [shell] check the status"
And Claude processes all in one turn
```

### Ask gets own turn
```
Given dude session is running and tells are buffered
When shell runs: el dude ask "what is the build status?"
Then buffered tells process first (one coalesced Claude turn)
Then the ask gets its own dedicated Claude turn
And shell receives the response
```

## Questions (Red -- parked)

- **Context problem**: recipient gets a decontextualized message. May need richer context injection beyond `[from name]`. Explore when it becomes friction.
- **Loops**: no TTL for now. If autonomous loops become a problem, add a hop counter then.
- **Coalesce format**: exact prompt format for coalesced messages TBD. Need to test what Claude responds well to.

## CRC Cards

| Object | Responsibilities | Collaborators |
|--------|-----------------|---------------|
| El.Session | buffer tells, drain buffer on claude-free, intercept stream for `@el_name`, deliver tells, log with metadata, filter self-routes | Registry, El.Session (target) |
| Registry | resolve names to PIDs, validate target alive | El.Session |
| Stream Interceptor | parse `@el_name` from Claude output, extract target + payload | El.Session |

## Glossary

| Term | Definition | Code anchor |
|------|-----------|-------------|
| **Session** | Named GenServer, an actor whose brain is an LLM | `El.Session`, `state.name` |
| **Tell** | Fire-and-forget message (cast) | `El.tell/2`, `GenServer.cast` |
| **Ask** | Blocking message, shell waits for response (deferred call) | `El.ask/2`, `GenServer.call` + noreply pattern |
| **@el_name** | Routing token Claude emits to address another session | stream interception |
| **From** | Return address — who sent the message | `[from name]` prefix |
| **Target** | Session being addressed | atom validated via Registry |
| **Relay** | El delivering a message from one session to another | `El.tell/2` triggered by stream interception |
| **Buffer** | Accumulated tells waiting for Claude to be free | `state.buffer` |
| **Coalesce** | Merging buffered tells into one Claude prompt | drain buffer on claude-free |
| **Actor** | An el session — receives messages, decides what to do, sends messages | Hewitt 1973, Erlang processes |
| **Log** | Message history, 4-element tuples | `state.messages` |
