defmodule El.CLI.Daemon do
  @behaviour El.CLI.Behaviours.Daemon

  defdelegate daemon_script, to: El.CLI.Daemon.Env
  defdelegate daemon_node, to: El.CLI.Daemon.Env
  defdelegate daemon_cookie, to: El.CLI.Daemon.Env
  defdelegate dev?, to: El.CLI.Daemon.Env

  def stop_daemon(opts \\ [])
  def stop_daemon(opts) when is_list(opts) do
    %{rpc: rpc, sleeper: sleeper, node_monitor: node_monitor, disconnect_timeout: disconnect_timeout, disconnect_poll_ms: disconnect_poll_ms} = stop_daemon_deps(opts)
    rpc.call(daemon_node(), :init, :stop, [])
    wait_for_node_disconnect(node_monitor, sleeper, timeout: disconnect_timeout, poll_ms: disconnect_poll_ms)
  end

  defp stop_daemon_deps(opts) do
    %{
      rpc: Keyword.get(opts, :rpc, El.Infra.RPC),
      sleeper: Keyword.get(opts, :sleeper, El.Infra.Sleeper),
      node_monitor: Keyword.get(opts, :node_monitor, El.Infra.NodeMonitor),
      disconnect_timeout: Keyword.get(opts, :disconnect_timeout, 5000),
      disconnect_poll_ms: Keyword.get(opts, :disconnect_poll_ms, 100)
    }
  end

  @impl true
  def restart_daemon(opts \\ [])
  def restart_daemon(opts) when is_list(opts) do
    stop_daemon(opts)
    %{system: system, node_connector: node_connector, net_kernel: net_kernel} = restart_daemon_deps(opts)
    spawn_daemon(system)
    connect_to_daemon(system, node_connector, net_kernel)
    :ok
  end

  defp restart_daemon_deps(opts) do
    %{
      system: Keyword.get(opts, :system, El.Infra.System),
      node_connector: Keyword.get(opts, :node_connector, El.Infra.NodeConnector),
      net_kernel: Keyword.get(opts, :net_kernel, El.Infra.NetKernel)
    }
  end

  def connect_to_daemon(system \\ El.Infra.System, node_connector \\ El.Infra.NodeConnector, net_kernel \\ El.Infra.NetKernel) do
    start_epmd(system)
    start_client_node(net_kernel, node_connector) |> handle_client_started(system, node_connector)
  end

  defp handle_client_started({:ok, _}, system, node_connector) do
    ensure_daemon(system, node_connector) |> handle_daemon_ready()
  end

  defp handle_client_started(_, _system, _node_connector), do: :local

  defp handle_daemon_ready(:ok), do: {:ok, daemon_node()}
  defp handle_daemon_ready(_), do: :local

  def start_daemon_node(system \\ El.Infra.System, node_connector \\ El.Infra.NodeConnector, net_kernel \\ El.Infra.NetKernel) do
    start_epmd(system)
    net_kernel.start([daemon_node(), :longnames])
    node_connector.set_cookie(daemon_cookie())
  end

  def ensure_daemon(system \\ El.Infra.System, node_connector \\ El.Infra.NodeConnector) do
    ensure_daemon_connected(node_connector.connect(daemon_node()), system, node_connector)
  end

  defp start_client_node(net_kernel, node_connector) do
    id = System.unique_integer([:positive])
    start_node_with_id(id, net_kernel, node_connector)
  end

  defp start_node_with_id(id, net_kernel, node_connector) do
    net_kernel.start([:"el-cli-#{id}@127.0.0.1", :longnames])
    |> maybe_set_cookie(node_connector)
  end

  defp maybe_set_cookie({:ok, _}, node_connector) do
    node_connector.set_cookie(daemon_cookie())
    {:ok, :started}
  end

  defp maybe_set_cookie(error, _node_connector), do: error

  defp ensure_daemon_connected(true, _system, _node_connector), do: :ok
  defp ensure_daemon_connected(false, system, _node_connector), do: spawn_and_wait(system)

  defp spawn_and_wait(system) do
    spawn_daemon(system)
    El.CLI.DaemonConnector.wait_for_daemon(30)
  end

  defp start_epmd(system) do
    system.cmd("epmd", ["-daemon"])
  end

  defp spawn_daemon(system) do
    script = daemon_script()
    prefix = dev?() |> env_prefix()
    system.cmd("sh", ["-c", "#{prefix}#{script} --daemon > /dev/null 2>&1 &"])
  end

  defp env_prefix(true), do: "DEV=1 "
  defp env_prefix(false), do: ""

  defp wait_for_node_disconnect(node_monitor, sleeper, timeout: max_ms, poll_ms: poll_interval) do
    wait_until_disconnected(node_monitor, sleeper, current_time_ms(), max_ms, poll_interval)
  end

  defp wait_until_disconnected(_node_monitor, _sleeper, start_ms, max_ms, _poll_interval) when start_ms >= max_ms do
    :ok
  end

  defp wait_until_disconnected(node_monitor, sleeper, start_ms, max_ms, poll_interval) do
    node_disconnected?(node_monitor)
    |> continue_or_retry(node_monitor, sleeper, start_ms, max_ms, poll_interval)
  end

  defp continue_or_retry(true, _node_monitor, _sleeper, _start_ms, _max_ms, _poll_interval), do: :ok

  defp continue_or_retry(false, node_monitor, sleeper, start_ms, max_ms, poll_interval) do
    sleeper.sleep(poll_interval)
    wait_until_disconnected(node_monitor, sleeper, start_ms + poll_interval, max_ms, poll_interval)
  end

  defp node_disconnected?(node_monitor) do
    not Enum.member?(node_monitor.list(), daemon_node())
  end

  defp current_time_ms do
    System.monotonic_time(:millisecond)
  end
end
