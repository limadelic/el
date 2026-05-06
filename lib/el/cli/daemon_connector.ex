defmodule El.CLI.DaemonConnector do
  def wait_for_daemon(n, sleeper \\ El.Infra.Sleeper, connector \\ El.NodeConnectorImpl)

  def wait_for_daemon(0, _sleeper, _connector), do: {:error, :timeout}

  def wait_for_daemon(n, sleeper, connector) when n > 0 do
    sleeper.sleep(100)
    n |> retry_with_daemon_node(sleeper, connector)
  end

  def check_connected(true, _n, _daemon_node, _sleeper, _connector) do
    :ok
  end

  def check_connected(false, n, _daemon_node, sleeper, connector) do
    wait_for_daemon(n - 1, sleeper, connector)
  end

  defp retry_with_daemon_node(n, sleeper, connector) do
    daemon_node = El.CLI.Daemon.daemon_node()
    daemon_node
    |> connector.connect()
    |> check_connected(n, daemon_node, sleeper, connector)
  end
end
