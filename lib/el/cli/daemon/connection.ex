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
    target = target_node(deps)
    is_connected = deps.node_connector.connect(target)
    ensure_daemon_result(is_connected, deps)
  end

  defp ensure_daemon_result(true, _deps) do
    :ok
  end

  defp ensure_daemon_result(false, deps) do
    fail_or_spawn(deps)
  end

  defp fail_or_spawn(deps) do
    if deps.env.remote_node() do
      raise "remote daemon unreachable: #{deps.env.remote_node()}"
    else
      spawn_and_wait(deps)
    end
  end

  @impl true
  def start_daemon_node(opts \\ []) do
    deps = prepare_deps(opts)
    start_epmd(deps)
    env = deps.env
    deps.net_kernel.start([El.CLI.Daemon.daemon_node(), env.naming_mode(env.host())])
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
    env = deps.env
    h = env.host()
    node_name = :"el-cli-#{id}@#{h}"
    result = deps.net_kernel.start([node_name, env.naming_mode(h)])
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
    target = target_node(deps)
    connected?(deps.node_connector.connect(target))
    |> handle_initial_connection(deps)
  end

  defp target_node(deps) do
    env = deps.env
    case env.remote_node() do
      nil -> El.CLI.Daemon.daemon_node()
      remote -> String.to_atom(remote)
    end
  end

  defp connected?(true), do: :ok
  defp connected?(false), do: :not_connected

  defp handle_initial_connection(:ok, _deps) do
    {:ok, El.CLI.Daemon.daemon_node()}
  end

  defp handle_initial_connection(:not_connected, deps) do
    fail_or_spawn(deps)
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
