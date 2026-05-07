defmodule El.CLI.Daemon.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon)
    Code.ensure_loaded!(El.Infra.Behaviours.System)
    Code.ensure_loaded!(El.Infra.Behaviours.NodeConnector)
    Code.ensure_loaded!(El.Infra.Behaviours.NetKernel)
    Code.ensure_loaded!(El.Infra.Behaviours.RPC)
    Code.ensure_loaded!(El.Infra.Behaviours.Sleeper)
    Code.ensure_loaded!(El.Infra.Behaviours.NodeMonitor)
    Code.ensure_loaded!(El.Infra.System)
    Code.ensure_loaded!(El.Infra.NodeConnector)
    Code.ensure_loaded!(El.Infra.NetKernel)
    Code.ensure_loaded!(El.Infra.RPC)
    Code.ensure_loaded!(El.Infra.Sleeper)
    Code.ensure_loaded!(El.Infra.NodeMonitor)
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

  describe "El.CLI.Daemon.stop_daemon/0" do
    setup do
      stub(El.MockRPC, :call, fn _node, :init, :stop, [] -> :ok end)
      stub(El.MockNodeMonitor, :list, fn -> [] end)
      stub(El.MockSleeper, :sleep, fn _ms -> :ok end)
      :ok
    end

    test "calls :init.stop on the daemon node via RPC" do
      expected = El.CLI.Daemon.daemon_node()
      expect(El.MockRPC, :call, fn ^expected, :init, :stop, [] -> :ok end)

      El.CLI.Daemon.stop_daemon(rpc: El.MockRPC, sleeper: El.MockSleeper, node_monitor: El.MockNodeMonitor)
    end

    test "invokes node monitor to check if node is still connected" do
      expect(El.MockNodeMonitor, :list, fn -> [] end)

      El.CLI.Daemon.stop_daemon(rpc: El.MockRPC, sleeper: El.MockSleeper, node_monitor: El.MockNodeMonitor)
    end
  end
end
