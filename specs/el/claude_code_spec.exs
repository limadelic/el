defmodule El.ClaudeCode.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(ClaudeCode.Session)
    on_exit(fn -> Application.delete_env(:claude_code, :cli_path) end)
    :ok
  end

  describe "start_link/1" do
    test "delegates to session module" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn _opts -> {:ok, :mock_pid} end)
      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "passes session_id to session module" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert Keyword.has_key?(opts, :session_id)
        assert is_binary(opts[:session_id])
        {:ok, :mock_pid}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "passes adapter configuration" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert Keyword.has_key?(opts, :adapter)
        assert is_tuple(opts[:adapter])
        {:ok, :mock_pid}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "passes dangerously_skip_permissions flag" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert opts[:dangerously_skip_permissions] == true
        {:ok, :mock_pid}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "includes model when provided" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        assert opts[:model] == "claude-3-5-haiku"
        {:ok, :mock_pid}
      end)

      El.ClaudeCode.start_link(
        model: "claude-3-5-haiku",
        session_module: ClaudeCode.Session
      )
    end

    test "omits model when not provided" do
      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        refute Keyword.has_key?(opts, :model)
        {:ok, :mock_pid}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "uses configured cli_path from application environment" do
      Application.put_env(:claude_code, :cli_path, "/custom/path")

      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == "/custom/path"
        {:ok, :mock_pid}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end

    test "defaults cli_path to :global when not configured" do
      Application.delete_env(:claude_code, :cli_path)

      Mimic.expect(ClaudeCode.Session, :start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == :global
        {:ok, :mock_pid}
      end)

      El.ClaudeCode.start_link(session_module: ClaudeCode.Session)
    end
  end

  describe "stream/2" do
    test "function exists and accepts pid and prompt" do
      assert function_exported?(El.ClaudeCode, :stream, 2)
    end
  end
end
