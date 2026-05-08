defmodule El.ClaudePort.Connection.PortSpawn.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.ClaudePort.Connection.PortSpawn)
    Code.ensure_loaded!(El.Infra.Behaviours.Env)
    :ok
  end

  setup :verify_on_exit!

  describe "El.ClaudePort.Connection.PortSpawn.spawn" do
    test "calls Env.get/0 to read environment variables" do
      expect(El.MockEnv, :get, fn -> %{} end)
      stub(El.MockPort, :open, fn _, _ -> {:ok, :port} end)

      Application.put_env(:el, :env_module, El.MockEnv)
      state = %{cwd: "/tmp", port_module: El.MockPort}
      El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)
      Application.delete_env(:el, :env_module)
    end

    test "returns ok port tuple from Port.open" do
      stub(El.MockEnv, :get, fn -> %{} end)
      expect(El.MockPort, :open, fn _, _ -> {:ok, :port} end)

      Application.put_env(:el, :env_module, El.MockEnv)
      state = %{cwd: "/tmp", port_module: El.MockPort}
      result = El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)
      Application.delete_env(:el, :env_module)

      assert result == {:ok, :port}
    end

    test "passes env vars to Port.open opts" do
      env_map = %{"FOO" => "BAR", "BAZ" => "QUX"}
      stub(El.MockEnv, :get, fn -> env_map end)
      expect(El.MockPort, :open, fn _, opts ->
        send(self(), {:port_opts, opts})
        {:ok, :port}
      end)

      Application.put_env(:el, :env_module, El.MockEnv)
      state = %{cwd: "/tmp", port_module: El.MockPort}
      El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)
      Application.delete_env(:el, :env_module)

      assert_received {:port_opts, opts}
      assert Enum.any?(opts, fn
        {:env, env_list} when is_list(env_list) -> true
        _ -> false
      end)
    end
  end
end
