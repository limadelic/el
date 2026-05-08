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
    test "reads environment variables via mocked Env when spawning port" do
      env_list = [{"TEST_VAR", "test_value"}]

      expect(El.MockEnv, :get, fn -> env_list end)
      expect(El.MockPort, :open, fn {_type, _exe}, opts ->
        assert Enum.any?(opts, fn
          {:env, env_charlist} when is_list(env_charlist) -> true
          _ -> false
        end)
        {:ok, :test_port}
      end)

      Application.put_env(:el, :env_module, El.MockEnv)

      state = %{cwd: "/tmp", port_module: El.MockPort}
      result = El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)

      assert result == {:ok, :test_port}

      Application.delete_env(:el, :env_module)
    end

    test "includes environment variables in port opts" do
      env_list = [{"PATH", "/bin"}, {"USER", "me"}]

      expect(El.MockEnv, :get, fn -> env_list end)
      expect(El.MockPort, :open, fn _spec, opts ->
        env_opt = Enum.find(opts, fn {k, _} -> k == :env end)
        assert {_, env_charlist} = env_opt
        assert env_charlist == [{~c"PATH", ~c"/bin"}, {~c"USER", ~c"me"}]
        {:ok, :port}
      end)

      Application.put_env(:el, :env_module, El.MockEnv)

      state = %{cwd: "/tmp", port_module: El.MockPort}
      El.ClaudePort.Connection.PortSpawn.spawn({:ok, {"echo", []}}, state)

      Application.delete_env(:el, :env_module)
    end
  end
end
