defmodule El.CLI.Daemon do
  @behaviour El.CLI.Behaviours.Daemon

  defdelegate daemon_script, to: El.CLI.Daemon.Env
  defdelegate daemon_node, to: El.CLI.Daemon.Env
  defdelegate daemon_cookie, to: El.CLI.Daemon.Env
  defdelegate dev?, to: El.CLI.Daemon.Env

  def stop_daemon(opts \\ [])
  def stop_daemon(opts) when is_list(opts) do
    %{rpc: rpc, sleeper: sleeper, node_monitor: node_monitor, env: env, disconnect_timeout: disconnect_timeout, disconnect_poll_ms: disconnect_poll_ms} = stop_daemon_deps(opts)
    rpc.call(daemon_node(), :init, :stop, [])
    wait_for_node_disconnect(node_monitor, sleeper, env, timeout: disconnect_timeout, poll_ms: disconnect_poll_ms)
  end

  defp stop_daemon_deps(opts) do
    defaults = %{rpc: El.Infra.RPC, sleeper: El.Infra.Sleeper, node_monitor: El.Infra.NodeMonitor, env: El.CLI.Daemon.Env, disconnect_timeout: 5000, disconnect_poll_ms: 100}
    Map.merge(defaults, Map.new(opts))
  end

  @impl true
  def restart_daemon(opts \\ [])
  def restart_daemon(opts) when is_list(opts) do
    stop_daemon(opts)
    %{connection: connection} = restart_daemon_deps(opts)
    connection.connect_to_daemon(opts)
    :ok
  end

  defp restart_daemon_deps(opts) do
    defaults = %{connection: El.CLI.Daemon.Connection}
    Map.merge(defaults, Map.new(opts))
  end

  defp wait_for_node_disconnect(node_monitor, sleeper, env, timeout: max_ms, poll_ms: poll_interval) do
    state = %{node_monitor: node_monitor, sleeper: sleeper, start_ms: current_time_ms(), max_ms: max_ms, poll_interval: poll_interval, env: env}
    wait_until_disconnected(state)
  end

  defp wait_until_disconnected(%{start_ms: start_ms, max_ms: max_ms}) when start_ms >= max_ms do
    :ok
  end

  defp wait_until_disconnected(%{node_monitor: node_monitor, env: env} = state) do
    node_disconnected?(node_monitor, env)
    |> continue_or_retry(state)
  end

  defp continue_or_retry(true, _state), do: :ok

  defp continue_or_retry(false, %{sleeper: sleeper, start_ms: start_ms, poll_interval: poll_interval} = state) do
    sleeper.sleep(poll_interval)
    wait_until_disconnected(%{state | start_ms: start_ms + poll_interval})
  end

  defp node_disconnected?(node_monitor, env) do
    not Enum.member?(node_monitor.list(), env.daemon_node())
  end

  defp current_time_ms do
    System.monotonic_time(:millisecond)
  end
end
