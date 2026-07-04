defmodule El.CLI.Daemon.Connection.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon.Connection)
    Code.ensure_loaded!(El.CLI.Daemon.Behaviours.Connection)
    Code.ensure_loaded!(El.Infra.Behaviours.System)
    Code.ensure_loaded!(El.Infra.Behaviours.NodeConnector)
    Code.ensure_loaded!(El.Infra.Behaviours.NetKernel)
    Code.ensure_loaded!(El.CLI.Daemon.Behaviours.Env)
    Code.ensure_loaded!(El.CLI.Daemon.Env)
    :ok
  end

  setup :verify_on_exit!

  describe "El.CLI.Daemon.Connection" do
    test "declares @behaviour El.CLI.Daemon.Behaviours.Connection" do
      assert El.CLI.Daemon.Behaviours.Connection in El.CLI.Daemon.Connection.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.CLI.Daemon.Connection.connect_to_daemon/1" do
    setup do
      stub(El.MockSystem, :cmd, fn _cmd, _args -> :ok end)
      stub(El.MockNodeConnector, :connect, fn _ -> true end)
      stub(El.MockNetKernel, :start, fn _args -> {:ok, :started} end)
      stub(El.MockNodeConnector, :set_cookie, fn _ -> true end)
      :ok
    end

    test "starts epmd via system" do
      expect(El.MockSystem, :cmd, fn "epmd", ["-daemon"] -> :ok end)

      El.CLI.Daemon.Connection.connect_to_daemon(
        system: El.MockSystem,
        node_connector: El.MockNodeConnector,
        net_kernel: El.MockNetKernel
      )
    end

    test "returns ok with daemon node when connected" do
      result = El.CLI.Daemon.Connection.connect_to_daemon(
        system: El.MockSystem,
        node_connector: El.MockNodeConnector,
        net_kernel: El.MockNetKernel
      )

      assert elem(result, 0) == :ok
    end
  end

  describe "El.CLI.Daemon.Connection.ensure_daemon/1" do
    setup do
      stub(El.MockSystem, :cmd, fn _cmd, _args -> :ok end)
      stub(El.MockNodeConnector, :connect, fn _ -> true end)
      :ok
    end

    test "returns ok when daemon is connected" do
      result = El.CLI.Daemon.Connection.ensure_daemon(
        system: El.MockSystem,
        node_connector: El.MockNodeConnector
      )

      assert result == :ok
    end
  end

  describe "El.CLI.Daemon.Connection.start_daemon_node/1" do
    setup do
      stub(El.MockSystem, :cmd, fn _cmd, _args -> :ok end)
      stub(El.MockNetKernel, :start, fn _args -> {:ok, :started} end)
      stub(El.MockNodeConnector, :set_cookie, fn _ -> true end)
      :ok
    end

    test "starts epmd then daemon node" do
      expect(El.MockSystem, :cmd, fn "epmd", ["-daemon"] -> :ok end)

      El.CLI.Daemon.Connection.start_daemon_node(
        system: El.MockSystem,
        node_connector: El.MockNodeConnector,
        net_kernel: El.MockNetKernel
      )
    end
  end
end
