defmodule El.ClaudeCode.Spec do
  use ExUnit.Case

  setup do
    Mox.verify_on_exit!(MockSessionModule)
    on_exit(fn -> Application.delete_env(:claude_code, :cli_path) end)
    :ok
  end

  describe "start_link/1" do
    test "delegates to session module" do
      Mox.expect(MockSessionModule, :start_link, 1, fn _opts ->
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "passes session_id to session module" do
      Mox.expect(MockSessionModule, :start_link, 1, fn opts ->
        assert Keyword.has_key?(opts, :session_id)
        assert is_binary(opts[:session_id])
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "passes adapter configuration" do
      Mox.expect(MockSessionModule, :start_link, 1, fn opts ->
        assert Keyword.has_key?(opts, :adapter)
        assert is_tuple(opts[:adapter])
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "passes dangerously_skip_permissions flag" do
      Mox.expect(MockSessionModule, :start_link, 1, fn opts ->
        assert opts[:dangerously_skip_permissions] == true
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "includes model when provided" do
      Mox.expect(MockSessionModule, :start_link, 1, fn opts ->
        assert opts[:model] == "claude-3-5-haiku"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(
        model: "claude-3-5-haiku",
        session_module: MockSessionModule
      )
    end

    test "omits model when not provided" do
      Mox.expect(MockSessionModule, :start_link, 1, fn opts ->
        refute Keyword.has_key?(opts, :model)
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "uses configured cli_path from application environment" do
      Application.put_env(:claude_code, :cli_path, "/custom/path")

      Mox.expect(MockSessionModule, :start_link, 1, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == "/custom/path"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "defaults cli_path to :global when not configured" do
      Application.delete_env(:claude_code, :cli_path)

      Mox.expect(MockSessionModule, :start_link, 1, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == :global
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end
  end

  describe "stream/2" do
    test "function exists and accepts pid and prompt" do
      assert function_exported?(El.ClaudeCode, :stream, 2)
    end
  end
end
