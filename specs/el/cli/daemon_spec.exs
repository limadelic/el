defmodule El.CLI.Daemon.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon)
    Code.ensure_loaded!(El.Infra.Behaviours.System)
    Code.ensure_loaded!(El.Infra.Behaviours.NodeConnector)
    Code.ensure_loaded!(El.Infra.Behaviours.NetKernel)
    Code.ensure_loaded!(El.Infra.System)
    Code.ensure_loaded!(El.Infra.NodeConnector)
    Code.ensure_loaded!(El.Infra.NetKernel)
    :ok
  end

  setup :verify_on_exit!

  describe "El.Infra.System" do
    test "declares @behaviour El.Infra.Behaviours.System" do
      assert El.Infra.Behaviours.System in El.Infra.System.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.Infra.NodeConnector" do
    test "declares @behaviour El.Infra.Behaviours.NodeConnector" do
      assert El.Infra.Behaviours.NodeConnector in El.Infra.NodeConnector.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.Infra.NetKernel" do
    test "declares @behaviour El.Infra.Behaviours.NetKernel" do
      assert El.Infra.Behaviours.NetKernel in El.Infra.NetKernel.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "host/0" do
    test "returns EL_HOST env var if set" do
      System.put_env("EL_HOST", "home.local")
      assert El.CLI.Daemon.host() == "home.local"
      System.delete_env("EL_HOST")
    end

    test "returns 127.0.0.1 as default" do
      System.delete_env("EL_HOST")
      assert El.CLI.Daemon.host() == "127.0.0.1"
    end
  end

  describe "remote_node/0" do
    test "returns EL_NODE env var if set" do
      System.put_env("EL_NODE", "el@home.local")
      assert El.CLI.Daemon.remote_node() == "el@home.local"
      System.delete_env("EL_NODE")
    end

    test "returns nil if EL_NODE not set" do
      System.delete_env("EL_NODE")
      assert El.CLI.Daemon.remote_node() == nil
    end
  end

  describe "daemon_node/0" do
    test "uses EL_HOST for non-dev daemon" do
      System.put_env("EL_HOST", "work.local")
      System.delete_env("DEV")
      assert El.CLI.Daemon.daemon_node() == :"el@work.local"
      System.delete_env("EL_HOST")
    end

    test "uses EL_HOST for dev daemon" do
      System.put_env("EL_HOST", "work.local")
      System.put_env("DEV", "1")
      assert El.CLI.Daemon.daemon_node() == :"el_dev@work.local"
      System.delete_env("EL_HOST")
      System.delete_env("DEV")
    end

    test "defaults to 127.0.0.1 when EL_HOST not set" do
      System.delete_env("EL_HOST")
      System.delete_env("DEV")
      assert El.CLI.Daemon.daemon_node() == :"el@127.0.0.1"
    end
  end

  describe "connect_to_daemon with EL_NODE" do
    test "does not spawn local daemon when remote reachable" do
      System.put_env("EL_NODE", "el@home.local")
      System.delete_env("EL_HOST")
      System.delete_env("DEV")
      expect(El.MockSystem, :cmd, 1, fn _, _ -> :ok end)
      expect(El.MockNodeConnector, :connect, 1, fn _ -> true end)
      expect(El.MockNodeConnector, :set_cookie, 1, fn _ -> true end)
      expect(El.MockNetKernel, :start, 1, fn [_, :longnames] -> {:ok, self()} end)

      result = El.CLI.Daemon.connect_to_daemon(El.MockSystem, El.MockNodeConnector, El.MockNetKernel)
      assert result == {:ok, :"el@127.0.0.1"}

      System.delete_env("EL_NODE")
    end

    @tag timeout: 1000
    test "fails with clear error when remote unreachable" do
      System.put_env("EL_NODE", "el@home.local")
      expect(El.MockSystem, :cmd, 1, fn _, _ -> :ok end)
      expect(El.MockNodeConnector, :connect, 1, fn _ -> false end)
      expect(El.MockNodeConnector, :set_cookie, 1, fn _ -> true end)
      expect(El.MockNetKernel, :start, 1, fn [_, :longnames] -> {:ok, self()} end)

      assert_raise RuntimeError, ~r/remote daemon unreachable/, fn ->
        El.CLI.Daemon.connect_to_daemon(El.MockSystem, El.MockNodeConnector, El.MockNetKernel)
      end

      System.delete_env("EL_NODE")
    end
  end

  describe "naming mode detection" do
    test "uses longnames for hostnames with dots" do
      System.delete_env("EL_HOST")
      System.delete_env("DEV")
      assert El.CLI.Daemon.daemon_node() == :"el@127.0.0.1"
      System.put_env("EL_HOST", "home.local")
      assert El.CLI.Daemon.daemon_node() == :"el@home.local"
      System.delete_env("EL_HOST")
    end

    test "uses shortnames for hostnames without dots" do
      System.put_env("EL_HOST", "localhost")
      assert El.CLI.Daemon.daemon_node() == :"el@localhost"
      System.put_env("EL_HOST", "myhost")
      assert El.CLI.Daemon.daemon_node() == :"el@myhost"
      System.delete_env("EL_HOST")
    end
  end
end
