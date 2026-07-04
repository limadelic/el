defmodule El.CLI.Daemon do
  def daemon_script do
    :escript.script_name() |> to_string() |> Path.expand()
  end

  def daemon_node do
    dev?() |> daemon_node_for(host())
  end

  def connect_to_daemon(sys \\ El.Infra.System, nc \\ El.Infra.NodeConnector, nk \\ El.Infra.NetKernel) do
    start_epmd(sys)
    start_client_node(nk, nc) |> handle_client_started(sys, nc)
  end

  defp handle_client_started({:ok, _}, system, node_connector) do
    ensure_daemon(system, node_connector) |> handle_daemon_ready()
  end

  defp handle_client_started(_, _system, _node_connector), do: :local

  defp handle_daemon_ready({:error, msg}) do
    raise msg
  end

  defp handle_daemon_ready(:ok), do: {:ok, daemon_node()}
  defp handle_daemon_ready(_), do: :local

  def start_daemon_node(system \\ El.Infra.System, nc \\ El.Infra.NodeConnector, nk \\ El.Infra.NetKernel) do
    start_epmd(system)
    nk.start([daemon_node(), naming_mode(host())])
    nc.set_cookie(daemon_cookie())
  end

  def dev? do
    dev_check(System.get_env("DEV"))
  end

  def host, do: System.get_env("EL_HOST", "127.0.0.1")
  def remote_node, do: System.get_env("EL_NODE")

  def ensure_daemon(sys \\ El.Infra.System, nc \\ El.Infra.NodeConnector) do
    target = target_or_local()
    case nc.connect(target) do
      true -> :ok
      false -> fail_or_spawn(sys)
    end
  end

  defp target_or_local(rn \\ remote_node()) do
    if rn, do: String.to_atom(rn), else: daemon_node()
  end

  defp fail_or_spawn(sys) do
    if remote_node() do
      {:error, "remote daemon unreachable: #{remote_node()}"}
    else
      spawn_and_wait(sys)
    end
  end

  defp daemon_node_for(true, host), do: :"el_dev@#{host}"
  defp daemon_node_for(false, host), do: :"el@#{host}"
  defp daemon_cookie, do: dev?() |> cookie_for()
  defp cookie_for(true), do: :el_dev
  defp cookie_for(false), do: :el
  defp naming_mode(h), do: (if String.contains?(h, "."), do: :longnames, else: :shortnames)
  defp dev_check(nil), do: :escript.script_name() |> to_string() |> Path.type() |> (fn :relative -> true; _ -> false end).()
  defp dev_check(_), do: true

  defp start_client_node(nk, nc) do
    id = System.unique_integer([:positive])
    nk.start([:"el-cli-#{id}@#{host()}", naming_mode(host())])
    |> maybe_set_cookie(nc)
  end

  defp maybe_set_cookie({:ok, _}, node_connector) do
    node_connector.set_cookie(daemon_cookie())
    {:ok, :started}
  end

  defp maybe_set_cookie(error, _node_connector), do: error

  defp spawn_and_wait(system) do
    spawn_daemon(system)
    case El.CLI.DaemonConnector.wait_for_daemon(30) do
      :ok -> :ok
      {:error, :timeout} -> {:error, "failed to start local daemon"}
    end
  end

  defp start_epmd(system), do: system.cmd("epmd", ["-daemon"])

  defp spawn_daemon(system) do
    system.cmd("sh", ["-c", "#{dev?() |> env_prefix()}#{daemon_script()} --daemon > /dev/null 2>&1 &"])
  end

  defp env_prefix(true), do: "DEV=1 "
  defp env_prefix(false), do: ""
end
