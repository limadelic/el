defmodule El.ClaudeCode.Spec do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  setup do
    on_exit(fn -> Application.delete_env(:claude_code, :cli_path) end)
    :ok
  end

  describe "start_link/1" do
    test "passes session_id from options" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert opts[:session_id] == "test-session-id"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_id: "test-session-id", session_module: El.MockClaudeCodeSession)
    end

    test "passes adapter configuration tuple" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert {ClaudeCode.Adapter.Port, _} = opts[:adapter]
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end

    test "passes dangerously_skip_permissions flag as true" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert opts[:dangerously_skip_permissions] == true
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end

    test "includes model when provided" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert opts[:model] == "claude-3-5-haiku"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(
        model: "claude-3-5-haiku",
        session_module: El.MockClaudeCodeSession
      )
    end

    test "omits model when not provided" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        refute Keyword.has_key?(opts, :model)
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end

    test "passes configured cli_path from application environment" do
      Application.put_env(:claude_code, :cli_path, "/custom/path")

      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == "/custom/path"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end

    test "defaults cli_path to :global when not configured" do
      Application.delete_env(:claude_code, :cli_path)

      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == :global
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end

    test "passes resume option when provided" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert opts[:resume] == "abc-123-def"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(
        resume: "abc-123-def",
        session_module: El.MockClaudeCodeSession
      )
    end

    test "omits resume option when not provided" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        refute Keyword.has_key?(opts, :resume)
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end

    test "start_link/1 passes :resume to session_module when given in opts" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert opts[:resume] == "abc"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_id: "abc", session_module: El.MockClaudeCodeSession, resume: "abc")
    end

    test "includes setting_sources in session options" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert opts[:setting_sources] == ["user", "project", "local"]
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end

    test "passes :resume to session module from env hook" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        assert opts[:resume] == "session-abc"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_id: "session-abc", resume: "session-abc")
    end

    test "omits session_id when not provided" do
      Mox.expect(El.MockClaudeCodeSession, :start_link, fn opts ->
        refute Keyword.has_key?(opts, :session_id)
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: El.MockClaudeCodeSession)
    end
  end

  describe "stream/2" do
    test "delegates to session module" do
      Mox.expect(El.MockClaudeCodeSession, :stream, fn pid, prompt ->
        assert pid == :test_pid
        assert prompt == "test prompt"
        {:ok, "streamed"}
      end)

      result = El.ClaudeCode.stream(:test_pid, "test prompt", session_module: El.MockClaudeCodeSession)
      assert result == {:ok, "streamed"}
    end
  end
end
