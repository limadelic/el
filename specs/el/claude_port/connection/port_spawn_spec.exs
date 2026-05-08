defmodule El.ClaudePort.Connection.PortSpawn.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.ClaudePort.Connection.PortSpawn)
    Code.ensure_loaded!(El.Infra.Behaviours.Env)
    Code.ensure_loaded!(El.Infra.Behaviours.Executable)
    :ok
  end

  setup :verify_on_exit!

  describe "El.ClaudePort.Connection.PortSpawn.spawn" do
    setup do
      Application.put_env(:el, :executable_module, El.MockExecutable)
      on_exit(fn -> Application.delete_env(:el, :executable_module) end)
      :ok
    end

    test "calls Env.get/0 to read environment variables" do
      expect(El.MockEnv, :get, fn -> %{} end)
      stub(El.MockPort, :open, fn _, _ -> {:ok, :port} end)
      stub(El.MockExecutable, :find, fn _ -> '/bin/echo' end)

      Application.put_env(:el, :env_module, El.MockEnv)
      state = %{cwd: "/tmp", port_module: El.MockPort}
      El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)
      Application.delete_env(:el, :env_module)
    end

    test "returns ok port tuple from Port.open" do
      stub(El.MockEnv, :get, fn -> %{} end)
      expect(El.MockPort, :open, fn _, _ -> {:ok, :port} end)
      stub(El.MockExecutable, :find, fn _ -> '/bin/echo' end)

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
      stub(El.MockExecutable, :find, fn _ -> '/bin/echo' end)

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

    test "calls Executable.find to locate the executable" do
      expect(El.MockExecutable, :find, fn 'echo' -> '/bin/echo' end)
      stub(El.MockEnv, :get, fn -> %{} end)
      stub(El.MockPort, :open, fn _, _ -> {:ok, :port} end)

      Application.put_env(:el, :env_module, El.MockEnv)
      state = %{cwd: "/tmp", port_module: El.MockPort}
      El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)
      Application.delete_env(:el, :env_module)
    end

    test "returns error when Executable.find returns false" do
      expect(El.MockExecutable, :find, fn 'notfound' -> false end)
      stub(El.MockEnv, :get, fn -> %{} end)

      Application.put_env(:el, :env_module, El.MockEnv)
      state = %{cwd: "/tmp", port_module: El.MockPort}
      result = El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"notfound", []}}, state)
      Application.delete_env(:el, :env_module)

      assert result == {:error, "CLI executable not found: notfound"}
    end

    test "passes found executable path to Port.open" do
      expect(El.MockExecutable, :find, fn 'echo' -> '/bin/echo' end)
      stub(El.MockEnv, :get, fn -> %{} end)
      expect(El.MockPort, :open, fn {:spawn_executable, path}, _ ->
        send(self(), {:exe_path, path})
        {:ok, :port}
      end)

      Application.put_env(:el, :env_module, El.MockEnv)
      state = %{cwd: "/tmp", port_module: El.MockPort}
      El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)
      Application.delete_env(:el, :env_module)

      assert_received {:exe_path, '/bin/echo'}
    end
  end
end
