defmodule El.CLI.Daemon do
  def daemon_script do
    :escript.script_name() |> to_string() |> Path.expand()
  end

  def daemon_node do
    dev?() |> daemon_node_for()
  end

  def connect_to_daemon(system \\ El.SystemImpl) do
    start_epmd(system)
    start_client_node() |> handle_client_started(system)
  end

  defp handle_client_started({:ok, _}, system) do
    ensure_daemon(system) |> handle_daemon_ready()
  end

  defp handle_client_started(_, _), do: :local

  defp handle_daemon_ready(:ok), do: {:ok, daemon_node()}
  defp handle_daemon_ready(_), do: :local

  def start_daemon_node(system \\ El.SystemImpl) do
    start_epmd(system)
    :net_kernel.start([daemon_node(), :longnames])
    Node.set_cookie(daemon_cookie())
  end

  def dev? do
    dev_check(System.get_env("DEV"))
  end

  def ensure_daemon(system \\ El.SystemImpl) do
    ensure_daemon_connected(Node.connect(daemon_node()), system)
  end

  defp daemon_node_for(true), do: :"el_dev@127.0.0.1"
  defp daemon_node_for(false), do: :"el@127.0.0.1"

  defp daemon_cookie_for(true), do: :el_dev
  defp daemon_cookie_for(false), do: :el

  defp daemon_cookie do
    dev?() |> daemon_cookie_for()
  end

  defp dev_check(nil), do: script_is_relative()
  defp dev_check(_), do: true

  defp script_is_relative do
    :escript.script_name() |> to_string() |> Path.type() |> is_relative()
  end

  defp is_relative(:relative), do: true
  defp is_relative(_), do: false

  defp start_client_node do
    id = System.unique_integer([:positive])
    start_node_with_id(id)
  end

  defp start_node_with_id(id) do
    :net_kernel.start([:"el-cli-#{id}@127.0.0.1", :longnames])
    |> maybe_set_cookie()
  end

  defp maybe_set_cookie({:ok, _}) do
    Node.set_cookie(daemon_cookie())
    {:ok, :started}
  end

  defp maybe_set_cookie(error), do: error

  defp ensure_daemon_connected(true, _system), do: :ok
  defp ensure_daemon_connected(false, system), do: spawn_and_wait(system)

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
end
