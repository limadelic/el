defmodule StubDaemonNode do
  def daemon_node, do: :"el@127.0.0.1"
end

defmodule El.CLI.DaemonConnector.Spec do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "wait_for_daemon/5" do
    test "happy path: connects on first attempt and returns :ok" do
      Mox.expect(El.MockSleeper, :sleep, 1, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, 1, fn _ -> true end)
      Mox.expect(El.MockRegistryReader, :select, 1, fn _ -> [] end)

      assert El.CLI.DaemonConnector.wait_for_daemon(5, El.MockSleeper, El.MockNodeConnector, El.MockRegistryReader, &StubDaemonNode.daemon_node/0) == :ok
    end

    test "retry path: fails twice then succeeds, sleeps exactly three times" do
      Mox.expect(El.MockSleeper, :sleep, 3, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, fn _ -> false end)
      Mox.expect(El.MockNodeConnector, :connect, fn _ -> false end)
      Mox.expect(El.MockNodeConnector, :connect, fn _ -> true end)
      Mox.expect(El.MockRegistryReader, :select, 1, fn _ -> [] end)

      assert El.CLI.DaemonConnector.wait_for_daemon(5, El.MockSleeper, El.MockNodeConnector, El.MockRegistryReader, &StubDaemonNode.daemon_node/0) == :ok
    end

    test "exhaustion path: always fails, sleeps exactly n times and returns timeout error" do
      n = 3
      Mox.expect(El.MockSleeper, :sleep, n, fn _ -> :ok end)
      Mox.expect(El.MockNodeConnector, :connect, n, fn _ -> false end)

      assert El.CLI.DaemonConnector.wait_for_daemon(n, El.MockSleeper, El.MockNodeConnector, El.MockRegistryReader, &StubDaemonNode.daemon_node/0) == {:error, :timeout}
    end
  end

  describe "wait_for_daemon/4" do
    test "uses default daemon_node_fn when not provided" do
      Mox.expect(El.MockSleeper, :sleep, 0, fn _ -> :ok end)

      assert El.CLI.DaemonConnector.wait_for_daemon(0, El.MockSleeper, El.MockNodeConnector, El.MockRegistryReader) == {:error, :timeout}
    end
  end

  describe "wait_for_daemon/3" do
    test "uses default registry reader and daemon_node_fn when not provided" do
      Mox.expect(El.MockSleeper, :sleep, 0, fn _ -> :ok end)

      assert El.CLI.DaemonConnector.wait_for_daemon(0, El.MockSleeper, El.MockNodeConnector) == {:error, :timeout}
    end
  end

  describe "wait_for_daemon/2" do
    test "uses default connector, registry reader, and daemon_node_fn when not provided" do
      Mox.expect(El.MockSleeper, :sleep, 0, fn _ -> :ok end)

      assert El.CLI.DaemonConnector.wait_for_daemon(0, El.MockSleeper) == {:error, :timeout}
    end
  end

  describe "wait_for_daemon/1" do
    test "uses all defaults when not provided" do
      assert El.CLI.DaemonConnector.wait_for_daemon(0) == {:error, :timeout}
    end
  end
end
