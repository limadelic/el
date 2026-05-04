defmodule El.CLI.DaemonConnector do
  def wait_for_daemon(n, sleeper \\ El.SleeperImpl, connector \\ El.NodeConnectorImpl, registry_reader \\ El.RegistryReaderImpl, daemon_node_fn \\ &El.CLI.Daemon.daemon_node/0)

  def wait_for_daemon(0, _sleeper, _connector, _registry_reader, _daemon_node_fn), do: {:error, :timeout}

  def wait_for_daemon(n, sleeper, connector, registry_reader, daemon_node_fn) when n > 0 do
    sleeper.sleep(100)
    n |> retry_with_daemon_node(sleeper, connector, registry_reader, daemon_node_fn)
  end

  def check_connected(true, n, daemon_node, sleeper, connector, registry_reader, daemon_node_fn) do
    daemon_node |> registry_reader.select() |> handle_rpc(n, sleeper, connector, registry_reader, daemon_node_fn)
  end

  def check_connected(false, n, _daemon_node, sleeper, connector, registry_reader, daemon_node_fn) do
    wait_for_daemon(n - 1, sleeper, connector, registry_reader, daemon_node_fn)
  end

  defp retry_with_daemon_node(n, sleeper, connector, registry_reader, daemon_node_fn) do
    daemon_node = daemon_node_fn.()
    daemon_node
    |> connector.connect()
    |> check_connected(n, daemon_node, sleeper, connector, registry_reader, daemon_node_fn)
  end

  defp handle_rpc({:badrpc, _}, n, sleeper, connector, registry_reader, daemon_node_fn) do
    wait_for_daemon(n - 1, sleeper, connector, registry_reader, daemon_node_fn)
  end

  defp handle_rpc(_, _n, _sleeper, _connector, _registry_reader, _daemon_node_fn) do
    :ok
  end
end
