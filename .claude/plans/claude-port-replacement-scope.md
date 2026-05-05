# El: Dropping claude_code Hex Dependency — Full Scope

**Status**: POC complete (`lib/el/claude_port.ex` replaces lazy-spawn race). Time to assess full de-coupling.

**Current situation**: El still calls 5 Claude Code modules. `ClaudePort` replaces Port-level logic; the remaining deps are CLI protocol and message parsing.

---

## 1. Inventory: What We Still Call

### Active dependencies in El:

| Module | Called from | Usage |
|--------|------------|-------|
| `ClaudeCode.CLI.Command` | `lib/el/claude_port.ex:177` | `build_args/3` — flatten opts to CLI flags |
| `ClaudeCode.CLI.Input` | `lib/el/claude_port.ex:63` | `user_message/2` — build NDJSON user message |
| `ClaudeCode.CLI.Parser` | `lib/el/claude_port.ex:219` | `normalize_keys/1` — convert camelCase JSON to snake_case |
| `ClaudeCode.Adapter.Port.Resolver` | `lib/el/claude_port.ex:175` | `find_binary/1` — resolve `claude` binary on disk |
| `ClaudeCode.Adapter.Port.Installer` | `lib/el/claude_port.ex:181` | `cli_not_found_message/0` — user-facing error msg |
| `ClaudeCode.Message.*` structs | `lib/el/session/claude.ex:54,60,66` | Pattern matching to extract `result`, `model`, `session_id` from events |
| `El.ClaudeCode` module | `lib/el/session.ex:15` | Wrapper around `ClaudeCode.Session` — builds adapter config |

### Not used:
- `ClaudeCode.Session` (the Hex dependency): El wraps it but doesn't directly call it. It's instantiated via `El.ClaudeCode.start_link` → `ClaudeCode.Session.start_link`.
- Message parsing (`ClaudeCode.CLI.Parser.parse_message`, `parse_stream`) — we don't use these; we hand-parse in `ClaudePort.process_lines`.

---

## 2. Replacement Effort Per Module

### A. `ClaudeCode.CLI.Command.build_args/3` — ~60 LOC

**Complexity**: Mechanical. Converts Elixir opts keyword list to CLI flag strings.

**What it does**:
- Takes `prompt`, `opts` keyword list, `session_id` (nil or string).
- Returns flat list of strings: `["--output-format", "stream-json", "--model", "claude-3-5-sonnet", "--resume", "sess-123", "hello"]`.

**El's actual needs**:
- Only a fraction of flags are used in El: `--output-format`, `--resume`, `--model`, `--agent`, `--system-prompt`, `--max-turns`, `--tools`, `--allowedTools`, `--dangerously-skip-permissions`, `--setting-sources`, `--debug`.
- Full Command module handles 50+ option types (sandbox, thinking, MCP, plugins, permission modes, etc.) — most not relevant to El's headless use.

**Replacement approach**:
- Extract needed options into a small, focused function in `El.ClaudePort`.
- Hand-code the 10-12 flags El actually uses.
- **LOC**: ~30 lines (vs. 486 in Command).

**Risk**: New CLI flags added to CC → El silently drops them. Acceptable if we version-pin the `claude` CLI binary.

---

### B. `ClaudeCode.CLI.Input.user_message/2` — ~10 LOC

**Complexity**: Trivial. Builds a single NDJSON user message.

**What it does**:
```elixir
%{
  type: "user",
  message: %{role: "user", content: content},
  session_id: session_id,
  parent_tool_use_id: null
} |> Jason.encode!
```

**Replacement**: Inline in `ClaudePort.handle_call` or extract to 5-line helper. **LOC**: ~5 lines.

---

### C. `ClaudeCode.CLI.Parser.normalize_keys/1` — ~20 LOC

**Complexity**: Mechanical recursive function. Converts camelCase → snake_case on JSON keys.

**What it does**:
- Recursively walks maps/lists.
- Applies `Macro.underscore/1` to string keys.
- Skips opaque keys (`"input"`, `"tool_input"`) to preserve user-defined parameter names.

**El's usage**: Called on every parsed JSON line from CLI output (line 219 in `claude_port.ex`).

**Replacement**: Copy the function into El as-is, or inline it. No logic changes needed. **LOC**: ~20 lines.

---

### D. `ClaudeCode.Adapter.Port.Resolver.find_binary/1` — ~80 LOC

**Complexity**: Tricky. Manages three resolution modes and auto-install logic.

**What it does**:
1. `:bundled` (default) — look in `priv/bin/claude`, auto-install if missing, verify version.
2. `:global` — search PATH and common locations (Darwin: `/usr/local/bin`, `/opt/homebrew/bin`; Linux: `/usr/bin`, `/usr/local/bin`; Windows: Registry).
3. Explicit path string — verify file exists.

**El's usage**: Called once per port open (line 175 in `claude_port.ex`).

**El's actual mode**: Always `:global` (from `Application.get_env(:claude_code, :cli_path, :global)` in line 22).

**Replacement approach**:
- **Minimal**: Just search PATH for `claude` binary + common locations. No auto-install, no version check (those belong in provisioning).
- **LOC**: ~15-20 lines of hand-coded search logic.

**Risk**: Loss of bundled binary and auto-install. Acceptable if El assumes `claude` is pre-installed or uses a release wrapper (currently: `/opt/homebrew/bin/el` is prod, `_build/dev/rel/el/bin/el_wrapper` is dev).

---

### E. `ClaudeCode.Adapter.Port.Installer.cli_not_found_message/0` — ~5 LOC

**Complexity**: Trivial. Returns a formatted error string.

**What it does**: Builds user-facing message suggesting install command for their OS.

**Replacement**: Hard-code a generic message or detect OS and suggest `brew install claude` (macOS) / `apt install claude` (Linux) / PowerShell (Windows). **LOC**: ~10 lines.

---

### F. `ClaudeCode.Message.ResultMessage`, `SystemMessage.Init` — Struct matching

**Complexity**: Structural, not behavioral. We only pattern-match on three fields.

**Current usage**:
```elixir
%ClaudeCode.Message.ResultMessage{result: result}
%ClaudeCode.Message.SystemMessage.Init{model: model, session_id: session_id}
```

**Replacement**: Define lightweight local structs or match on raw maps with keys. El parses NDJSON → maps; these come from CC's canonical JSON format. **LOC**: ~10 lines (three pattern-match guards).

---

## 3. Hidden Risks

### Environment handling
- CC reads `CLAUDE_API_KEY`, `ANTHROPIC_API_KEY`, and other env vars. We pass `System.get_env()` directly to Port (line 149).
- **Risk**: If CC changes env var names, El breaks.
- **Mitigation**: Document the env vars El requires; add a validation step at startup.

### CLI versioning
- Resolver verifies installed binary matches SDK's pinned version.
- **Risk**: CC updates CLI interface (flags, output format) → El's hand-coded parsers fail.
- **Mitigation**: Version-pin the `claude` binary in El's release or documentation. Test against a known version.

### Stream-json format changes
- Parser knows 20+ message types (init, result, stream_event, tool_progress, etc.).
- **Risk**: New message types from new CLI → El silently drops them (currently acceptable — we only look for `type: "result"` and `type: "system", subtype: "init"`).
- **Current code** (line 244-250): We only check for `type: "result"` and `type: "system"`. Other message types are ignored.
- **Mitigation**: Add logging when unknown message types are dropped. Subscribe to CC's release notes.

### Sandbox and MCP configuration
- Command module preprocesses `:sandbox` option into `:settings` JSON.
- **Risk**: El doesn't currently use sandbox or MCP, so safe to drop.
- **Verification**: Grep confirms neither `:sandbox` nor `:mcp_servers` appear in El code.

### Tool and permission handling
- Command converts tool lists and permission modes into flags.
- **Current El**: Hardcodes `dangerously_skip_permissions: true` in `el/claude_code.ex:44`.
- **Risk**: If we add tool support later, we need to re-implement option conversion.
- **Safe for now**.

---

## 4. Recommended Order of Operations

### Phase 1: Extract and shrink (1 day)
1. Copy `ClaudeCode.CLI.Parser.normalize_keys/1` into `El.ClaudePort`.
2. Extract `user_message/2` logic inline in `handle_call`.
3. Hand-code a minimal `build_cli_args/2` function (~30 LOC).
4. Keep Resolver and Installer calls for now (easier than bootstrapping CLI detection).

### Phase 2: Drop resolver and installer (1 day)
1. Replace `Resolver.find_binary/1` with a simple PATH search + fallback paths.
2. Replace `Installer.cli_not_found_message/0` with a generic or OS-aware message.
3. Test on macOS, Linux, Windows (or skip Windows if not needed).

### Phase 3: Drop message structs (1 day)
1. Replace pattern-matching on `ClaudeCode.Message.*` structs with map guards.
2. Verify tests still green.

### Phase 4: Remove dependency from mix.exs (1 hour)
1. Delete `{:claude_code, "~> 0.36"}` from `deps()`.
2. Remove `alias ClaudeCode.*` from `El.ClaudePort`.
3. Update `El.ClaudeCode` module — decide whether to keep it (wrapper around our own logic) or inline its logic into Session.

---

## 5. Effort Estimate

### Total scope: 2–3 days

- **Phase 1 (extract)**: 4–6 hours. Mechanical, low risk.
- **Phase 2 (resolver/installer)**: 4–6 hours. CLI binary resolution is straightforward; OS detection for error messages adds ~1 hour.
- **Phase 3 (message structs)**: 1–2 hours. Pattern matching → map guards is straightforward.
- **Phase 4 (cleanup)**: 30 minutes.
- **Testing + buffer**: 4–6 hours.

**Not an iceberg** — all logic is mechanical and testable. No hidden architectural dependencies. The POC already proved Port-level isolation works.

---

## 6. Residual Complexity

### What becomes El's responsibility
1. **CLI argument building** — We must stay in sync with `claude` CLI's flag names.
2. **Stream-json format parsing** — We must stay in sync with Claude CLI's output format.
3. **Binary discovery** — We own the PATH search and error messages.

### How to manage it
- **Document**: Add comments listing the exact CLI version(s) El is tested against.
- **Test**: Add specs that verify known message types are extracted correctly.
- **Monitor**: Subscribe to Claude CLI release notes for breaking changes.

---

## Conclusion

Dropping `claude_code` is **feasible and low-risk** because:
1. We only use a small, mechanical slice of it (CLI args + NDJSON + key normalization).
2. The POC already isolated Port logic.
3. No hidden dependencies or callbacks we're unaware of.

**Recommendation**: Do Phase 1 (extract) first to reduce surface area. Measure impact. Then decide whether to finish Phases 2–3.

**Ownership**: This is an El-only change. No downstream impact on Dude or CC. Safe to ship incrementally.
