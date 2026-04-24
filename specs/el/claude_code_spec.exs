defmodule El.ClaudeCode.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(ClaudeCode.Session)
    on_exit(fn -> Application.delete_env(:claude_code, :cli_path) end)
    :ok
  end

  describe "start_link/1" do
    test "passes session_id from options" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert opts[:session_id] == "test-session-id"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_id: "test-session-id", session_module: ClaudeCode.Session)
    end

    test "passes adapter configuration tuple" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert {ClaudeCode.Adapter.Port, _} = opts[:adapter]
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "passes dangerously_skip_permissions flag as true" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert opts[:dangerously_skip_permissions] == true
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "includes model when provided" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert opts[:model] == "claude-3-5-haiku"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(
        model: "claude-3-5-haiku",
        session_module: ClaudeCode.Session
      )
    end

    test "omits model when not provided" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        refute Keyword.has_key?(opts, :model)
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "passes configured cli_path from application environment" do
      Application.put_env(:claude_code, :cli_path, "/custom/path")

      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == "/custom/path"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "defaults cli_path to :global when not configured" do
      Application.delete_env(:claude_code, :cli_path)

      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == :global
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "passes resume option when provided" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert opts[:resume] == "abc-123-def"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(
        resume: "abc-123-def",
        session_module: ClaudeCode.Session
      )
    end

    test "omits resume option when not provided" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        refute Keyword.has_key?(opts, :resume)
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end
  end

  describe "stream/2" do
    test "delegates to session module" do
      Mimic.expect(ClaudeCode.Session, :stream, fn _pid, _prompt -> :ok end)
      El.ClaudeCode.stream(:pid, "prompt")
    end
  end
end
