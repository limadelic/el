defmodule El.ClaudeCode.Spec do
  use ExUnit.Case

  setup do
    on_exit(fn -> Application.delete_env(:claude_code, :cli_path) end)
    :ok
  end

  describe "start_link/1" do
    test "delegates to session module" do
      El.ClaudeCode.start_link(session_module: MockSessionModule)
    end

    test "passes session_id to session module" do
      {:ok, agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:claude_code, :capture_agent, agent)

      defmodule SessionIdCapture do
        def start_link(opts) do
          agent = Application.get_env(:claude_code, :capture_agent)
          Agent.update(agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.ClaudeCode.start_link(session_module: SessionIdCapture)

      captured_opts = Agent.get(agent, & &1)
      assert Keyword.has_key?(captured_opts, :session_id)
      assert is_binary(captured_opts[:session_id])

      Application.delete_env(:claude_code, :capture_agent)
    end

    test "passes adapter configuration" do
      {:ok, agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:claude_code, :capture_agent, agent)

      defmodule AdapterCapture do
        def start_link(opts) do
          agent = Application.get_env(:claude_code, :capture_agent)
          Agent.update(agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.ClaudeCode.start_link(session_module: AdapterCapture)

      captured_opts = Agent.get(agent, & &1)
      assert Keyword.has_key?(captured_opts, :adapter)
      assert is_tuple(captured_opts[:adapter])

      Application.delete_env(:claude_code, :capture_agent)
    end

    test "passes dangerously_skip_permissions flag" do
      {:ok, agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:claude_code, :capture_agent, agent)

      defmodule PermissionsCapture do
        def start_link(opts) do
          agent = Application.get_env(:claude_code, :capture_agent)
          Agent.update(agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.ClaudeCode.start_link(session_module: PermissionsCapture)

      captured_opts = Agent.get(agent, & &1)
      assert captured_opts[:dangerously_skip_permissions] == true

      Application.delete_env(:claude_code, :capture_agent)
    end

    test "includes model when provided" do
      {:ok, agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:claude_code, :capture_agent, agent)

      defmodule ModelCapture do
        def start_link(opts) do
          agent = Application.get_env(:claude_code, :capture_agent)
          Agent.update(agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.ClaudeCode.start_link(
        model: "claude-3-5-haiku",
        session_module: ModelCapture
      )

      captured_opts = Agent.get(agent, & &1)
      assert captured_opts[:model] == "claude-3-5-haiku"

      Application.delete_env(:claude_code, :capture_agent)
    end

    test "omits model when not provided" do
      {:ok, agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:claude_code, :capture_agent, agent)

      defmodule NoModelCapture do
        def start_link(opts) do
          agent = Application.get_env(:claude_code, :capture_agent)
          Agent.update(agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.ClaudeCode.start_link(session_module: NoModelCapture)

      captured_opts = Agent.get(agent, & &1)
      refute Keyword.has_key?(captured_opts, :model)

      Application.delete_env(:claude_code, :capture_agent)
    end

    test "uses configured cli_path from application environment" do
      Application.put_env(:claude_code, :cli_path, "/custom/path")
      {:ok, agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:claude_code, :capture_agent, agent)

      defmodule CliPathCapture do
        def start_link(opts) do
          agent = Application.get_env(:claude_code, :capture_agent)
          Agent.update(agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.ClaudeCode.start_link(session_module: CliPathCapture)

      captured_opts = Agent.get(agent, & &1)
      {ClaudeCode.Adapter.Port, adapter_opts} = captured_opts[:adapter]
      assert adapter_opts[:cli_path] == "/custom/path"

      Application.delete_env(:claude_code, :capture_agent)
    end

    test "defaults cli_path to :global when not configured" do
      Application.delete_env(:claude_code, :cli_path)
      {:ok, agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:claude_code, :capture_agent, agent)

      defmodule DefaultCliPathCapture do
        def start_link(opts) do
          agent = Application.get_env(:claude_code, :capture_agent)
          Agent.update(agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.ClaudeCode.start_link(session_module: DefaultCliPathCapture)

      captured_opts = Agent.get(agent, & &1)
      {ClaudeCode.Adapter.Port, adapter_opts} = captured_opts[:adapter]
      assert adapter_opts[:cli_path] == :global

      Application.delete_env(:claude_code, :capture_agent)
    end
  end

  describe "stream/2" do
    test "function exists and accepts pid and prompt" do
      assert function_exported?(El.ClaudeCode, :stream, 2)
    end
  end
end
