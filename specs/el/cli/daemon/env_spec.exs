defmodule El.CLI.Daemon.Env.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon.Env)
    Code.ensure_loaded!(El.CLI.Daemon.Behaviours.Env)
    Code.ensure_loaded!(El.Infra.Behaviours.Env)
    :ok
  end

  setup :verify_on_exit!

  describe "El.CLI.Daemon.Env" do
    test "declares @behaviour El.CLI.Daemon.Behaviours.Env" do
      assert El.CLI.Daemon.Behaviours.Env in El.CLI.Daemon.Env.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.CLI.Daemon.Env.dev?" do
    test "returns true when DEV env is set via mocked Env" do
      expect(El.MockEnv, :get, fn "DEV" -> "1" end)
      Application.put_env(:el, :env_module, El.MockEnv)

      assert El.CLI.Daemon.Env.dev? == true

      Application.delete_env(:el, :env_module)
    end

    test "returns true when DEV env is set to any non-nil value via mocked Env" do
      expect(El.MockEnv, :get, fn "DEV" -> "yes" end)
      Application.put_env(:el, :env_module, El.MockEnv)

      assert El.CLI.Daemon.Env.dev? == true

      Application.delete_env(:el, :env_module)
    end

    test "returns false when DEV env is nil via mocked Env" do
      expect(El.MockEnv, :get, fn "DEV" -> nil end)
      Application.put_env(:el, :env_module, El.MockEnv)

      assert El.CLI.Daemon.Env.dev? == false

      Application.delete_env(:el, :env_module)
    end
  end

  describe "El.CLI.Daemon.Env.daemon_node" do
    test "returns el_dev@127.0.0.1 when dev? is true" do
      expect(El.MockEnv, :get, fn "DEV" -> "1" end)
      Application.put_env(:el, :env_module, El.MockEnv)

      assert El.CLI.Daemon.Env.daemon_node() == :"el_dev@127.0.0.1"

      Application.delete_env(:el, :env_module)
    end

    test "returns el@127.0.0.1 when dev? is false" do
      expect(El.MockEnv, :get, fn "DEV" -> nil end)
      Application.put_env(:el, :env_module, El.MockEnv)

      assert El.CLI.Daemon.Env.daemon_node() == :"el@127.0.0.1"

      Application.delete_env(:el, :env_module)
    end
  end

  describe "El.CLI.Daemon.Env.daemon_cookie" do
    test "returns el_dev when dev? is true" do
      expect(El.MockEnv, :get, fn "DEV" -> "1" end)
      Application.put_env(:el, :env_module, El.MockEnv)

      assert El.CLI.Daemon.Env.daemon_cookie() == :el_dev

      Application.delete_env(:el, :env_module)
    end

    test "returns el when dev? is false" do
      expect(El.MockEnv, :get, fn "DEV" -> nil end)
      Application.put_env(:el, :env_module, El.MockEnv)

      assert El.CLI.Daemon.Env.daemon_cookie() == :el

      Application.delete_env(:el, :env_module)
    end
  end
end
