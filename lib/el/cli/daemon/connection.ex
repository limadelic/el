defmodule El.CLI.Daemon.Connection do
  @behaviour El.CLI.Daemon.Behaviours.Connection

  @impl true
  def connect_to_daemon(opts \\ []) do
    deps = prepare_deps(opts)
    start_epmd(deps)
    start_client_node(deps)
  end

  @impl true
  def ensure_daemon(opts \\ []) do
    deps = prepare_deps(opts)
    daemon_node = El.CLI.Daemon.daemon_node()
    is_connected = deps.node_connector.connect(daemon_node)
    ensure_daemon_result(is_connected, deps)
  end

  defp ensure_daemon_result(true, _deps) do
    :ok
  end

  defp ensure_daemon_result(false, deps) do
    spawn_and_wait(deps)
  end

  @impl true
  def start_daemon_node(opts \\ []) do
    deps = prepare_deps(opts)
    start_epmd(deps)
    deps.net_kernel.start([El.CLI.Daemon.daemon_node(), :longnames])
    deps.node_connector.set_cookie(El.CLI.Daemon.daemon_cookie())
  end

  defp prepare_deps(opts) do
    Map.merge(default_deps(), Map.new(opts))
  end

  defp default_deps do
    %{system: El.Infra.System, node_connector: El.Infra.NodeConnector, net_kernel: El.Infra.NetKernel, env: El.CLI.Daemon.Env}
  end

  defp start_client_node(deps) do
    id = System.unique_integer([:positive])
    node_name = :"el-cli-#{id}@127.0.0.1"
    result = deps.net_kernel.start([node_name, :longnames])
    maybe_set_cookie_and_handle(result, deps)
  end

  defp maybe_set_cookie_and_handle({:ok, _}, deps) do
    deps.node_connector.set_cookie(El.CLI.Daemon.daemon_cookie())
    ensure_daemon_or_spawn(deps)
  end

  defp maybe_set_cookie_and_handle(_error, _deps) do
    :local
  end

  defp ensure_daemon_or_spawn(deps) do
    daemon_node = El.CLI.Daemon.daemon_node()
    connected?(deps.node_connector.connect(daemon_node))
    |> handle_initial_connection(deps)
  end

  defp connected?(true), do: :ok
  defp connected?(false), do: :not_connected

  defp handle_initial_connection(:ok, _deps) do
    {:ok, El.CLI.Daemon.daemon_node()}
  end

  defp handle_initial_connection(:not_connected, deps) do
    spawn_and_wait(deps)
  end

  defp spawn_and_wait(deps) do
    spawn_daemon(deps)
    El.CLI.DaemonConnector.wait_for_daemon(30)
  end

  defp start_epmd(deps) do
    deps.system.cmd("epmd", ["-daemon"])
  end

  defp spawn_daemon(deps) do
    script = El.CLI.Daemon.daemon_script()
    prefix = El.CLI.Daemon.dev?() |> env_prefix()
    deps.system.cmd("sh", ["-c", "#{prefix}#{script} --daemon > /dev/null 2>&1 &"])
  end

  defp env_prefix(true), do: "DEV=1 "
  defp env_prefix(false), do: ""
end
