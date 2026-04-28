defmodule El.CLI.DaemonConnector do
  def wait_for_daemon(0), do: {:error, :timeout}

  def wait_for_daemon(n) do
    :timer.sleep(100)
    n |> retry_with_daemon_node()
  end

  def check_connected(true, n, daemon_node) do
    daemon_node |> rpc_registry_select() |> handle_rpc(n)
  end

  def check_connected(false, n, _daemon_node) do
    wait_for_daemon(n - 1)
  end

  defp retry_with_daemon_node(n) do
    El.CLI.Daemon.daemon_node()
    |> Node.connect()
    |> check_connected(n, El.CLI.Daemon.daemon_node())
  end

  defp rpc_registry_select(daemon_node) do
    :rpc.call(daemon_node, Registry, :select, [
      El.Registry,
      [{{:"$1", :_, :_}, [], [:"$1"]}]
    ])
  end

  defp handle_rpc({:badrpc, _}, n) do
    wait_for_daemon(n - 1)
  end

  defp handle_rpc(_, _n) do
    :ok
  end
end
