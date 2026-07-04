defmodule El.CLI.DaemonConnector.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon)
    Code.ensure_loaded!(El.CLI.DaemonConnector)
    El.CLI.Daemon.dev?()
    :ok
  end

  setup :verify_on_exit!

  describe "wait_for_daemon/3" do
    test "happy path: connects on first attempt and returns :ok" do
      Mox.expect(El.MockSleeper, :sleep, 1, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, 1, fn _ -> true end)

      assert El.CLI.DaemonConnector.wait_for_daemon(5, El.MockSleeper, El.MockNodeConnector) == :ok
    end

    test "retry path: fails twice then succeeds, sleeps exactly three times" do
      Mox.expect(El.MockSleeper, :sleep, 3, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, fn _ -> false end)
      Mox.expect(El.MockNodeConnector, :connect, fn _ -> false end)
      Mox.expect(El.MockNodeConnector, :connect, fn _ -> true end)

      assert El.CLI.DaemonConnector.wait_for_daemon(5, El.MockSleeper, El.MockNodeConnector) == :ok
    end

    test "exhaustion path: always fails, sleeps exactly n times and returns timeout error" do
      n = 3
      Mox.expect(El.MockSleeper, :sleep, n, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, n, fn _ -> false end)

      assert El.CLI.DaemonConnector.wait_for_daemon(n, El.MockSleeper, El.MockNodeConnector) == {:error, :timeout}
    end
  end

  describe "wait_for_daemon with EL_NODE" do
    test "uses remote node when EL_NODE is set" do
      System.put_env("EL_NODE", "el@home.local")
      Mox.expect(El.MockSleeper, :sleep, 1, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, 1, fn node ->
        node == :"el@home.local"
      end)

      assert El.CLI.DaemonConnector.wait_for_daemon(5, El.MockSleeper, El.MockNodeConnector) == :ok
      System.delete_env("EL_NODE")
    end

    test "uses local daemon node when EL_NODE is not set" do
      System.delete_env("EL_NODE")
      System.delete_env("EL_HOST")
      System.delete_env("DEV")
      Mox.expect(El.MockSleeper, :sleep, 1, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, 1, fn node ->
        node == :"el@127.0.0.1"
      end)

      assert El.CLI.DaemonConnector.wait_for_daemon(5, El.MockSleeper, El.MockNodeConnector) == :ok
    end
  end
end
