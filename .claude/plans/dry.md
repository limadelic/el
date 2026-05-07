# El DRY audit

Cartman audits, one per file. Each section: file + bullet violations.

## lib/el/cli.ex
- Lines 42-48: `execute(:tell_ask, ...)` and `execute(:ask_tell, ...)` identical structure, only Messaging fn name differs — unify
- Lines 27-40: 3 `:start` clauses each build opts then call handler — extract common pattern
- Lines 62-68: `:exit` and `:clear` clauses identical pattern (Pattern.pattern? then *_by_kind) — collapse

## lib/el/cli/start.ex
- Lines 2-3, 5-6, 21-22, 34-35: 4 nil/value pairs (`start_opts`, `normalize_model`, `agent_opt`, `subagent_model`) — collapse with default args
- Lines 37-41 vs 43-47: `handle_find_daemon_for_start` vs `handle_find_daemon_with_rest` — already being unified
- Lines 49-55: `dispatch_rest` two clauses could collapse

## lib/el/claude_code.ex
- Lines 25-26 & 60-61: `extract_session_module` and `extract_stream_session_module` identical — consolidate
- Lines 40-41, 43-44, 52-53: `add_model`/`add_agent`/`add_resume` same nil-check + append pattern — generic `add_option`
- Lines 48-50: `add_resume_if_present` is unnecessary wrapper over `add_resume` — inline
- Lines 37-38: `base_perms`/`base_settings` single-use one-liners — inline at line 30

## lib/el/session.ex
- Lines 68-75: `handle_call(:log,...)` and `handle_call({:log,_},...)` both route to `LogHandler.handle_log/2` — collapse
- Lines 83-91: 5 wrappers `handle_call(X, from, state) do CallHandler.handle(X, from, state) end` — single catch-all at end
- Lines 46-48: `modules_and_callbacks(o)` is pure indirection over `get_opts(o)` — remove
- Lines 37-44: `base_state(n,s,o)` abbrev names — expand to `(name, session_id, opts)`

## lib/el/session/claude.ex
- Lines 15-20 + 70-77: `check_alive/2` and `check_claude_alive/2` identical — merge
- Lines 36-38: `stream/2` wrapper has no logic — inline into `ask/2`
- Lines 60-62: `ask_work/3` ignores routes param, just calls `ask/2` — delete, callers use `ask/2`

## lib/el.ex
- Lines 38-58: 6+ session API delegators all same shape — single delegation factory
- Lines 68-79: exit_pattern/clear_pattern/log_pattern share filter pipeline — extract
- Lines 1-6: 5 injected deps all same `Application.get_env` shape — consolidate

## lib/el/agent_detector.ex
- Lines 5, 9, 13: `[global_path(name), local_path(name)]` repeated 3x — use `paths/1` everywhere
- Lines 23-26 + 28-30: `["agents", "#{name}.md"]` suffix duplicated — extract `agent_filename/1`

## lib/el/cli/messaging.ex
- Lines 4-6 vs 9-11: handle_tell_ask + handle_ask_tell identical — single handler with op param
- Lines 30-32, 36-38, 42-43: `String.to_atom(name)` repeated 3x — helper
- Lines 32, 38, 43: `Enum.join(words, " ")` repeated — helper
- Lines 14-24: agent_safe try/catch + resolve_name fallback — flatten

## lib/el/cli/pattern.ex
- Lines 8-12: exit_by_kind/clear_by_kind same dispatch — single by_kind helper
- Lines 14-22 + 24-32: exit_pattern/exit_single + clear_pattern/clear_single same shape — unified handle_operation

## lib/el/cli/router.ex
- Lines 7-8: two `:daemon` clauses — merge `["--daemon", _name | _rest]`
- Lines 22, 26, 30, 34: `[<<c, _::binary>>] when c != ?-` repeated — extract helper

## lib/el/cli/log.ex
CLEAN — no DRY violations.

## lib/el/application.ex
- Lines 22, 28, 59, 64, 69, 74: `Application.get_env(:el, :message_store, El.MessageStore)` repeated 6x — extract helper

## lib/el/behaviours.ex
- 5 behaviour modules in one file — split (one-module-per-file rule)

## lib/el/cli/daemon_connector.ex
- Lines 6 & 20: `daemon_node()` called twice — bind once
- Lines 10 & 24: redundant param/retrieval — derive inside retry helper
- Lines 30-31 & 13-14: `wait_for_daemon(n - 1)` duplicated — extract

## lib/el/cli/daemon.ex
- Lines 38-39 + 41-42: daemon_node_for + daemon_cookie_for true/false pairs — data table
- Lines 7 + 45: `dev?() |> daemon_*_for()` chain repeated — co-call
- Lines 55-56: is_relative wrapper — inline
- Lines 68-73: maybe_set_cookie wrapper — inline
- Lines 75-76: ensure_daemon_connected true/false — inline

## lib/el/cli/output.ex
- Lines 39-40 + 47-48: handle_not_found/1 called identically in two places — extract or merge
- Lines 55-62: log_line/1 two clauses repeat tuple destructure + `"> #{message}"` — consolidate
- Lines 68-72: format_line/2 two clauses both compute padding — consolidate

## lib/el/dets_backend.ex
- Whole module is transparent wrappers around `:dets` calls — DELETE module OR keep as behaviour-only

## lib/el/adapters/file.ex
CLEAN.

## lib/el/file_system_impl.ex
CLEAN.

## lib/el/lifecycle.ex
- Lines 6 + 8: `def exit(name), do: do_exit(name)` is pure pass-through — inline
- Line 9: `name |> lookup() |> exit_found(name)` re-passes name — refactor
- Lines 16-19: `rescue _ -> :ok` swallows all errors — narrow or remove

## lib/el/message_store.ex
- Lines 3, 9, 15, 21, 26: `Application.get_env(:el, :dets_backend, El.DetsBackend)` repeated 5x — extract helper

## lib/el/port_adapter.ex
CLEAN.

## lib/el/process_monitor.ex
- Lines 4 + 6: `cleanup(name)` duplicated in receive happy path + after timeout — single exit

## lib/el/pty.ex
- Lines 40 + 56: `File.open(~c"/dev/tty", [...])` repeats — module attrs
- Lines 75 + 81: `port_module.command(pty, x)` repeated — send_to_pty helper
- Lines 85-87 vs 89-91: stdin_loop ↔ process_stdin_read indirection — inline

## lib/el/session_adapter.ex
CLEAN.

## lib/el/session/api.ex
- Lines 11,15,19,23,27,31,35,47: `Registry.via_tuple(name)` repeated 8x — extract `defp via/1`
- Lines 15-16 + 35-36: `:infinity` timeout repeated — module attr

## lib/el/session/ask.ex
- Lines 27-28: delete_ask_entry + store_ask_entry pair — single replace_ask_entry call

## lib/el/session/call_handler.ex
- Line 18 inlines `{:reply, ..., Store.store_relay_entry(state, entry)}` while line 31 uses `reply_ok/1` helper — apply consistently

## lib/el/session/cast_handler.ex
- Lines 26-28 + 33-35: identical entry tuple + messages append — extract build_relay_entry + store_relay
- Line 16: Router.process_tell_response result discarded
- Missing spec file

## lib/el/session/crash.ex
CLEAN.

## lib/el/session/info_handler.ex
CLEAN.

## lib/el/session/log_handler.ex
- Lines 2-4 + 6-8: handle_log(:log,...) and handle_log({:log,:all},...) return same `{:reply, state.messages, state}` — delegate one to the other

## lib/el/session/registry.ex
- Lines 3 + 7: `El.Registry` referenced twice — module attr `@registry`
- Line 7: `[{_pid, _}]` pattern leak — encapsulate via helper

## lib/el/session/router.ex
- Lines 34-37 & 57-60: identical self-route guard — extract helper
- Lines 15-26, 40-42, 63-66, 70-74, 78-80: route_if_alive closure pattern repeated 5x — parameterize destination
- Lines 88-89 & 47: `Registry.via_tuple(target)` — bind once
- Lines 46, 64, 72, 79: `envelope(state.name, ...)` repeated 4x — extract

## lib/el/session/store.ex
- Lines 10-13, 24-27, 46, 58: tuple `{"type", message, "", %{ref: ref}}` constructed 4x — extract pending_entry
- Lines 17-20 + 39: store_tell_entry + store_relay_entry both store + append same way — extract store_and_append
- Lines 43-49 + 56-60: store_ask_immediate + store_tell_immediate identical — merge with type param
- Lines 66-72: replace_tell + replace_ask thin wrappers — merge into replace_entry

## lib/el/session/tell.ex
- Lines 6-12: function body has multiple sequential ops — restructure via pattern matching
- Lines 22-28: spawn_tell_task intermediate server_pid — inline

## lib/el/session/terminator.ex
CLEAN.

## lib/el/credo/line_check.ex
- Lines 16-21: extract_end_line delegates to extract_end_line_impl (pure indirection) — collapse
- Lines 34-41: build_issue + update_issue_fields tuple unpack ceremony — merge
- Line 30: intermediate `pri` var — inline

## lib/el/credo/max_function_lines.ex + max_module_lines.ex
Two modules ~97% identical. Extract base `El.Credo.ContainerCheck` parameterized by:
- AST pattern ({:def, :defp, :defmacro} vs {:defmodule})
- Default max_lines (5 vs 100)
- Entity name ("Function" vs "Module")
Shared (move to base): param_defaults/0, explanations/0, run/2, maybe_add_issue/4, add_issue/5
Per-module: only AST pattern + config tuple

## lib/el/session/id.ex
- Lines 3-4 in generate_session_id: bit pattern `48, 4, 12, 2, 62` duplicated (only `_::4` → `4::4` differs) — extract pattern
- Missing spec file
