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
    Code.ensure_loaded!(El.CLI.Daemon.Behaviours.Env)
    Code.ensure_loaded!(El.CLI.Daemon.Env)
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

  describe "El.CLI.Daemon.Env" do
    test "declares @behaviour El.CLI.Daemon.Behaviours.Env" do
      assert El.CLI.Daemon.Behaviours.Env in El.CLI.Daemon.Env.module_info(:attributes)[:behaviour] || []
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

    test "accepts env parameter for dependency injection" do
      stub(El.MockDaemonEnv, :daemon_node, fn -> :"el_dev@127.0.0.1" end)
      expect(El.MockNodeMonitor, :list, fn -> [] end)

      El.CLI.Daemon.stop_daemon(rpc: El.MockRPC, sleeper: El.MockSleeper, node_monitor: El.MockNodeMonitor, env: El.MockDaemonEnv)
    end
  end

  describe "El.CLI.Daemon.restart_daemon/1" do
    setup do
      stub(El.MockRPC, :call, fn _node, :init, :stop, [] -> :ok end)
      stub(El.MockNodeMonitor, :list, fn -> [] end)
      stub(El.MockSleeper, :sleep, fn _ms -> :ok end)
      stub(El.MockSystem, :cmd, fn _cmd, _args -> :ok end)
      stub(El.MockNodeConnector, :connect, fn _ -> true end)
      stub(El.MockNetKernel, :start, fn _args -> {:ok, :started} end)
      stub(El.MockNodeConnector, :set_cookie, fn _ -> true end)
      :ok
    end

    test "spawns a fresh daemon after stopping" do
      expect(El.MockSystem, :cmd, 2, fn
        "epmd", ["-daemon"] -> :ok
        "sh", ["-c", _cmd] -> :ok
      end)

      El.CLI.Daemon.restart_daemon(
        rpc: El.MockRPC,
        sleeper: El.MockSleeper,
        node_monitor: El.MockNodeMonitor,
        system: El.MockSystem,
        node_connector: El.MockNodeConnector,
        net_kernel: El.MockNetKernel
      )
    end

    test "returns ok when daemon restarts successfully" do
      result = El.CLI.Daemon.restart_daemon(
        rpc: El.MockRPC,
        sleeper: El.MockSleeper,
        node_monitor: El.MockNodeMonitor,
        system: El.MockSystem,
        node_connector: El.MockNodeConnector,
        net_kernel: El.MockNetKernel
      )

      assert result == :ok
    end
  end
end
