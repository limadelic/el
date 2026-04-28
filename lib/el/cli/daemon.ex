defmodule El.CLI.Daemon do
  def daemon_script do
    :escript.script_name() |> to_string() |> Path.expand()
  end

  def daemon_node do
    dev?() |> daemon_node_for()
  end

  def connect_to_daemon do
    start_epmd()
    start_client_node() |> handle_client_started()
  end

  defp handle_client_started({:ok, _}) do
    ensure_daemon() |> handle_daemon_ready()
  end

  defp handle_client_started(_), do: :local

  defp handle_daemon_ready(:ok), do: {:ok, daemon_node()}
  defp handle_daemon_ready(_), do: :local

  def start_daemon_node do
    start_epmd()
    :net_kernel.start([daemon_node(), :longnames])
    Node.set_cookie(:el)
  end

  def dev? do
    dev_check(System.get_env("DEV"))
  end

  def ensure_daemon do
    ensure_daemon_connected(Node.connect(daemon_node()))
  end

  defp daemon_node_for(true), do: :"el_dev@127.0.0.1"
  defp daemon_node_for(false), do: :"el@127.0.0.1"

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
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    :net_kernel.start([:"el-cli-#{id}@127.0.0.1", :longnames])
    |> maybe_set_cookie()
  end

  defp maybe_set_cookie({:ok, _}) do
    Node.set_cookie(:el)
    {:ok, :started}
  end

  defp maybe_set_cookie(error), do: error

  defp ensure_daemon_connected(true), do: :ok
  defp ensure_daemon_connected(false), do: spawn_and_wait()

  defp spawn_and_wait do
    spawn_daemon()
    wait_for_daemon(30)
  end

  defp start_epmd do
    System.cmd("epmd", ["-daemon"])
  end

  defp spawn_daemon do
    script = daemon_script()
    prefix = dev?() |> env_prefix()
    System.cmd("sh", ["-c", "#{prefix}#{script} --daemon > /dev/null 2>&1 &"])
  end

  defp env_prefix(true), do: "DEV=1 "
  defp env_prefix(false), do: ""

  defp wait_for_daemon(0), do: {:error, :timeout}

  defp wait_for_daemon(n) do
    :timer.sleep(100)
    daemon_node() |> Node.connect() |> check_connected(n)
  end

  defp check_connected(true, n) do
    case :rpc.call(daemon_node(), Registry, :select, [El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}]]) do
      {:badrpc, _} -> wait_for_daemon(n - 1)
      _ -> :ok
    end
  end

  defp check_connected(false, n), do: wait_for_daemon(n - 1)
end
