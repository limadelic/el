# El Log Plan

## STATUS

1. Log pagination — DONE v0.1.84
2. Ask pending state — DONE v0.1.84
3. DETS dedup fix — DONE v0.1.85. DetsBackend wrapper, delete pending before storing completed.
4. Clear command — DONE. `el bob clear` kills Port, new session_id, clears messages+DETS.
5. Rename kill → exit — DONE. Renamed across all layers + added log cleanup on exit.

---

## HOW CLAUDE CODE SESSIONS WORK (verified from source v2 — Kent source dive 2026-04-26)

### Three layers
1. **El** (`~/dev/self/el/`) — GenServer per session, generates/stores session_id
2. **Elixir SDK** (`~/dude/code/`) — ClaudeCode.Session GenServer, Port adapter to CLI
3. **Claude Code CLI** (`~/dev/ext/claude-code/`) — TypeScript, the actual claude binary

### Session chain
```
El.Session.init() → generates UUID session_id
  → El.ClaudeCode.start_link(session_id: sid)
    → ClaudeCode.Session.start_link(adapter: Port, session_id: sid)
      → Port spawns: claude --resume <sid> --output-format stream-json -p
```

### Port is PERSISTENT ✅ (verified from print.ts:2816)
- One Erlang Port (OS subprocess) per Session for entire lifetime
- Same Port handles multiple stream() calls sequentially
- Claude CLI process stays alive between messages — NOT a new process per call
- Message loop: `for await (const message of structuredIO.structuredInput)` continuously reads stdin
- Process only exits when: stdin closes, `end_session` control request received, or SIGINT/SIGTERM
- Conversation context maintained both in-memory (CLI process) AND on disk (JSONL)

### Stdin/Stdout Protocol ✅ (verified from structuredIO.ts)
- Both directions: **NDJSON** (newline-delimited JSON)
- **Stdin** (structuredIO.ts:333-350): each line parsed as JSON, type `StdinMessage | SDKMessage`
  - Empty lines silently skipped
  - `keep_alive` messages silently ignored
- **Stdout** message types (controlTypes.ts):
  - `stream_event` — token deltas, tool calls during generation
  - `result` — final generation result
  - `system` — status, hook_started, etc.
  - `control_request` / `control_response` — tool permission flow
  - `prompt_suggestion`, `auth_status`
- Streaming is real-time: messages enqueued to `structuredIO.outbound` (a Stream) continuously, not buffered

### Session resume ✅ (verified from print.ts:5030-5078)
- `--resume <id>` loads at **STARTUP ONLY**, not per-message
- Calls `loadConversationForResume(sessionId, jsonlFile)` — loads FULL JSONL transcript from disk
- All messages loaded into memory as `initialMessages` (line 680), passed to message loop
- Model sees full context on first turn; subsequent messages accumulate in-memory only
- `--resume-session-at <uuid>` truncates to that message index (line 5107-5120)
- No --resume = fresh conversation (empty initialMessages)

### Session storage ✅ (verified from sessionStorage.ts:403)
- JSONL at: `~/.cache/claude/<sessionId>.jsonl`
- One JSON object per line, appended via `appendEntryToFile` (line 768+)
- Entry fields: type, role, content, uuid, timestamp, parentUuid
- Progress messages NOT persisted (marked ephemeral, line 134-138)
- Old transcripts persist on disk even after clear/kill

### /clear command ✅ (verified from commands/clear/conversation.ts:49-251)
1. Fires SessionEnd hooks (line 69)
2. Clears messages: `setMessages(() => [])` (line 109)
3. Generates new session_id UUID (line 203)
4. Sets old as parentSessionId (analytics lineage)
5. Writes new session_id to `CLAUDE_CODE_SESSION_ID` env var (line 206)
6. Resets file pointer (line 208)
7. Clears: tasks (kills foreground, keeps background), attribution, file history, MCP clients/tools (preserves pluginReconnectKey), standalone agent context
8. Clears caches: readFileState, discoveredSkillNames, loadedNestedMemoryPaths (line 130-132)
9. Resets working directory to original (line 129)
10. Re-persists session metadata for new session (line 237-242)
11. Fires SessionStart hooks (line 245)

### Headless mode (-p) ✅ (verified from print.ts)
- Entry point: `runHeadless()` at print.ts:484
- No React TUI — subscribes directly to settings changes (line 520)
- No /clear command available — no slash command parser in headless
- To start fresh: don't pass --resume (or use new session_id)
- `--no-session-persistence` CLI flag was REMOVED (GitHub issue #20398 requesting restoration)
- Internally still controlled by `ENABLE_SESSION_PERSISTENCE` env var (source: print.ts:5064)
- For El: can set this env var when spawning Port to avoid disk clutter

### Signal handling ✅ (verified from gracefulShutdown.ts:256-297)
- **SIGINT**: aborts in-flight query via `abortController.abort()`, then `gracefulShutdown(0)` (print.ts:1032-1034)
- **SIGTERM**: `gracefulShutdown(143)` (line 270)
- **SIGHUP**: `gracefulShutdown(129)` (line 275)
- **Cleanup sequence** (line 391-523): failsafe timer (5s) → exit alt-screen → run cleanup fns → SessionEnd hooks → log analytics → force exit
- If cleanup hangs: failsafe force-exits after 5s (line 417-425)

### How to end a headless session ✅ (verified from print.ts:2850-2862)
- Close stdin (EOF) → `inputClosed = true` (line 254), loop exits
- Send `control_request` with `subtype: 'end_session'` → `break` at line 2862
- Kill process (SIGTERM/SIGINT) → graceful shutdown with cleanup

---

## COMMAND ALIGNMENT (with Claude Code)

| Claude Code | El CLI | El API | Status |
|-------------|--------|--------|--------|
| `/clear` | `el bob clear` | `El.clear(:bob)` | TODO — implement first |
| `/exit` | `el bob exit` | `El.exit(:bob)` | TODO — rename from kill, add log cleanup |

### Exit (rename from kill)
- Aligns with Claude Code's `/exit`
- Tears down GenServer entirely via DynamicSupervisor.terminate_child
- Claude Port dies with GenServer (linked process) → triggers SIGHUP → graceful shutdown (5s max)
- Session gone from registry
- TODO: rename `El.kill/1` → `El.exit/1`, add `El.Application.delete_session_messages(name)` after termination
- To use again: `el bob` starts completely fresh

### Clear (new command — implement first)
- Aligns with Claude Code's `/clear`
- GenServer stays alive, same registry entry, same daemon connection
- Kills the Claude Port process (SIGTERM or close stdin → triggers graceful shutdown)
- Generates new session_id
- Starts new Claude Port with new session_id (no --resume = fresh conversation)
- Clears state.messages to []
- Clears DETS messages
- Next message starts a brand new Claude conversation
- `maybe_respawn_claude` stays as-is — internal crash recovery (same session_id, --resume)

### Why clear exists (not just exit+restart)
- Exit loses GenServer, requires restart overhead
- Clear is instant reset without infrastructure churn
- Same dude, clean slate

### Clear implementation
Files:
- `session.ex`: add `handle_call(:clear, ...)`:
  1. Kill claude_pid (Process.exit or GenServer.stop → Port gets SIGHUP, 5s cleanup)
  2. Generate new session_id
  3. Start new Claude process via claude_module.start_link (no --resume)
  4. Clear state.messages to []
  5. Delete DETS messages
  6. Return {:reply, :ok, new_state}
- `el.ex`: add `El.clear(name)` → `GenServer.call(via_tuple(name), :clear)`
- `cli.ex`: add `parse_route([_name, "clear"])` → `:clear`, wire execute

---

## VERIFIED FACTS (current code state as of v0.1.85)

### Message format
- 4-tuple: `{type, message, response, metadata}`
- Types: `"tell"`, `"ask"`, `"relay"`, `"crash"`
- DETS (`:bag`) at `~/.el/messages.dets`, also in state.messages

### Storage (tell and ask both use pending pattern now)
- store_tell_immediate/store_ask_immediate → pending entry with ref
- On completion → replace_tell/replace_ask updates in-memory + deletes pending from DETS + stores completed
- DetsBackend wrapper makes DETS mockable

### El.Session state
- name, claude_pid, session_id, messages, pending_calls
- claude_module, task_module, alive_fn, registry_module, opts

### maybe_respawn_claude
- Triggered when claude_pid is nil (after crash)
- Reuses same session_id → conversation resumes (--resume loads full transcript at startup)
- For clear: need to respawn with NEW session_id instead (no --resume = fresh)

### Port communication model ✅ (corrected from v1)
- Port IS a continuous stdin/stdout pipe — NDJSON both directions
- Each `stream()` call writes a JSON message to stdin of the same long-lived CLI process
- CLI message loop reads it, runs generation, streams NDJSON events on stdout, then waits for next stdin message
- `--resume <sid>` loads transcript at STARTUP ONLY — subsequent messages accumulate in-memory
- Think: persistent REPL over pipes, not request/response

---

## NEXT SESSION

### Ready to implement
1. **Clear command** — katmandu (kent→kenny→cartman):
   - Design is complete above
   - Three files: `session.ex`, `el.ex`, `cli.ex`
   - Key insight: kill Port (triggers 5s graceful shutdown), new session_id, new Port (no --resume), clear messages
2. **Rename kill → exit** + log cleanup:
   - Rename `El.kill/1` → `El.exit/1`
   - Add `El.Application.delete_session_messages(name)` after termination
   - Update CLI routing

### Three codebases to reference
| Layer      | Path              | What matters                          |
|------------|-------------------|---------------------------------------|
| El         | `~/dev/self/el/`  | Session GenServer, clear/kill logic   |
| Elixir SDK | `~/dude/code/`    | ClaudeCode.Session, Port adapter      |
| Claude CLI | `~/dev/ext/claude-code/` | /clear source, session persistence |
