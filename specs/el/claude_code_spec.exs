defmodule El.ClaudeCode.Spec do
  use ExUnit.Case

  setup do
    Mox.verify_on_exit!(MockSessionModule)
    on_exit(fn -> Application.delete_env(:claude_code, :cli_path) end)
    :ok
  end

  setup do
    MockSessionModule
    |> Mox.stub(:start_link, fn opts ->
      assert Keyword.has_key?(opts, :session_id)
      assert Keyword.has_key?(opts, :adapter)
      assert Keyword.has_key?(opts, :dangerously_skip_permissions)
      assert opts[:dangerously_skip_permissions] == true
      {:ok, self()}
    end)

    :ok
  end

  describe "start_link/1" do
    test "passes correct opts to session start_link" do
      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "includes model in opts when provided" do
      MockSessionModule
      |> Mox.expect(:start_link, fn opts ->
        assert opts[:model] == "claude-3-5-haiku"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(
        model: "claude-3-5-haiku",
        session_module: MockSessionModule
      )
    end

    test "omits model from opts when not provided" do
      MockSessionModule
      |> Mox.expect(:start_link, fn opts ->
        refute Keyword.has_key?(opts, :model)
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "reads cli_path from Application config" do
      Application.put_env(:claude_code, :cli_path, "/custom/path")

      MockSessionModule
      |> Mox.expect(:start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == "/custom/path"
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "defaults to :global when cli_path not configured" do
      Application.delete_env(:claude_code, :cli_path)

      MockSessionModule
      |> Mox.expect(:start_link, fn opts ->
        {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
        assert adapter_opts[:cli_path] == :global
        {:ok, self()}
      end)

      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end
  end

  describe "stream/2" do
    test "function exists and delegates to session" do
      assert function_exported?(El.ClaudeCode, :stream, 2)
    end
  end
end
