defmodule El.CLI.DaemonConnector do
  def wait_for_daemon(n, sleeper \\ El.SleeperImpl)

  def wait_for_daemon(0, _sleeper), do: {:error, :timeout}

  def wait_for_daemon(n, sleeper) when n > 0 do
    sleeper.sleep(100)
    n |> retry_with_daemon_node(sleeper)
  end

  def check_connected(true, n, daemon_node, sleeper) do
    daemon_node |> rpc_registry_select() |> handle_rpc(n, sleeper)
  end

  def check_connected(false, n, _daemon_node, sleeper) do
    wait_for_daemon(n - 1, sleeper)
  end

  defp retry_with_daemon_node(n, sleeper) do
    El.CLI.Daemon.daemon_node()
    |> Node.connect()
    |> check_connected(n, El.CLI.Daemon.daemon_node(), sleeper)
  end

  defp rpc_registry_select(daemon_node) do
    :rpc.call(daemon_node, Registry, :select, [
      El.Registry,
      [{{:"$1", :_, :_}, [], [:"$1"]}]
    ])
  end

  defp handle_rpc({:badrpc, _}, n, sleeper) do
    wait_for_daemon(n - 1, sleeper)
  end

  defp handle_rpc(_, _n, _sleeper) do
    :ok
  end
end
