defmodule El.CLI do
  def main(args) do
    main_impl(args)
    System.halt(0)
  end

  defp main_impl([]) do
    IO.puts(
      "usage: el ls | el <name> | el <name> tell <message> | el <name> ask <message> | el <name> log | el <name> kill | el kill all"
    )
  end

  defp main_impl(["ls"]) do
    ensure_epmd()

    case find_daemon_node() do
      {:ok, daemon_node} ->
        :rpc.call(daemon_node, El, :local_ls, [])
        |> Enum.each(fn name ->
          IO.puts(Atom.to_string(name))
        end)

      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el <name>")
        System.halt(1)
    end
  end

  defp main_impl(["--daemon", name]) do
    daemon_node = ensure_daemon_node()
    name_atom = String.to_atom(name)

    if daemon_node && daemon_node != Node.self() do
      :rpc.call(daemon_node, El, :start, [name_atom])
    else
      El.start(name_atom)
    end

    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end

  defp main_impl([name]) do
    ensure_epmd()

    case find_daemon_node() do
      {:ok, daemon_node} ->
        name_atom = String.to_atom(name)
        :rpc.call(daemon_node, El, :start, [name_atom])
        IO.puts("el: #{name} is up")

      :not_found ->
        spawn_daemon(name)
    end
  end

  defp main_impl([name, "tell" | words]) do
    ensure_epmd()
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)

    case find_daemon_node() do
      {:ok, daemon_node} ->
        :rpc.call(daemon_node, El, :tell, [name_atom, msg])

      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")
        System.halt(1)
    end
  end

  defp main_impl([name, "ask" | words]) do
    ensure_epmd()
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)

    case find_daemon_node() do
      {:ok, daemon_node} ->
        case :rpc.call(daemon_node, El, :ask, [name_atom, msg]) do
          {:badrpc, reason} ->
            IO.puts(:stderr, "Error: #{inspect(reason)}")
            System.halt(1)

          response ->
            IO.puts(response)
        end

      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")
        System.halt(1)
    end
  end

  defp main_impl([name, "log"]) do
    ensure_epmd()
    name_atom = String.to_atom(name)

    case find_daemon_node() do
      {:ok, daemon_node} ->
        log = :rpc.call(daemon_node, El, :log, [name_atom])

        log
        |> Enum.each(fn {type, message, response} ->
          IO.puts("[#{type}] #{message}")
          IO.puts(response)
        end)

      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")
        System.halt(1)
    end
  end

  defp main_impl([name, "kill"]) do
    ensure_epmd()
    name_atom = String.to_atom(name)

    case find_daemon_node() do
      {:ok, daemon_node} ->
        :rpc.call(daemon_node, El, :kill, [name_atom])

      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")
        System.halt(1)
    end
  end

  defp main_impl(["kill", "all"]) do
    :os.cmd(~c"pkill -9 beam 2>/dev/null")
    :os.cmd(~c"pkill -9 epmd 2>/dev/null")
    :timer.sleep(500)

    cleanup_stale_node(Path.expand("~/.el/daemon_node"))

    burrito_cache = Path.expand("~/Library/Application Support/.burrito")

    case File.ls(burrito_cache) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&String.starts_with?(&1, "el_"))
        |> Enum.each(fn dir ->
          File.rm_rf!(Path.join(burrito_cache, dir))
        end)

      _ ->
        :ok
    end

    IO.puts("All sessions killed")
  end

  defp main_impl(_) do
    main_impl([])
  end

  defp ensure_daemon_node do
    ensure_epmd()

    if Node.alive?() do
      write_daemon_node()
      Node.self()
    else
      case Node.start(:"el@127.0.0.1") do
        {:ok, _} ->
          Node.set_cookie(:el)
          Application.ensure_all_started(:el)
          write_daemon_node()
          Node.self()

        {:error, {:already_started, _}} ->
          Node.set_cookie(:el)
          Application.ensure_all_started(:el)
          write_daemon_node()
          Node.self()

        {:error, _reason} ->
          nuke_epmd()
          # After nuke, retry with exponential backoff in case kernel still holds the port
          retry_start_node(5)
      end
    end
  end

  defp find_daemon_node do
    # Try to find an existing daemon node (for client invocations)
    ensure_epmd()

    case read_daemon_node() do
      {:ok, daemon_node} ->
        # Daemon node file exists, try to connect to it
        if Node.alive?() do
          # We're already a node, can RPC directly
          {:ok, daemon_node}
        else
          # Not yet a node, start a client node and connect
          case try_connect_daemon() do
            {:ok, node} -> {:ok, node}
            :not_found -> :not_found
          end
        end

      :not_found ->
        :not_found
    end
  end

  defp ensure_epmd do
    try do
      System.cmd("epmd", ["-daemon"], stderr_to_stdout: true)
    catch
      _, _ -> :ok
    end

    :timer.sleep(100)
  end

  defp nuke_epmd do
    # Query stale nodes BEFORE restarting epmd
    stale_ports =
      case :erl_epmd.names() do
        {:ok, names} ->
          names
          |> Enum.filter(fn {node_name, _port} ->
            String.starts_with?(to_string(node_name), "el")
          end)
          |> Enum.map(fn {_node_name, port} -> port end)

        _ ->
          []
      end

    # Kill any processes listening on those ports
    Enum.each(stale_ports, fn port ->
      case :os.cmd(~c"lsof -ti :#{port} 2>/dev/null | head -1") do
        [] ->
          :ok

        pid_str ->
          pid = pid_str |> List.to_string() |> String.trim()

          if pid != "" do
            :os.cmd(~c"kill -9 #{pid} 2>/dev/null")
          end
      end
    end)

    # Kill epmd itself to clear its registry
    System.cmd("pkill", ["-9", "epmd"], stderr_to_stdout: true)
    :timer.sleep(500)
    System.cmd("epmd", ["-daemon"], stderr_to_stdout: true)
    :timer.sleep(200)
  end

  defp read_daemon_node do
    node_file = Path.expand("~/.el/daemon_node")

    case File.read(node_file) do
      {:ok, content} ->
        node_name = content |> String.trim() |> String.to_atom()
        {:ok, node_name}

      {:error, :enoent} ->
        :not_found
    end
  end

  defp try_connect_daemon do
    node_file = Path.expand("~/.el/daemon_node")

    case File.read(node_file) do
      {:ok, content} ->
        node_name = content |> String.trim() |> String.to_atom()

        try do
          # If we're not alive, start a client node
          if not Node.alive?() do
            client_node = :"el_client_#{System.os_time()}@127.0.0.1"

            start_task = Task.async(fn -> Node.start(client_node) end)

            case Task.yield(start_task, 2000) || Task.shutdown(start_task) do
              {:ok, {:ok, _}} ->
                :ok

              {:ok, {:error, {:already_started, _}}} ->
                :ok

              _ ->
                cleanup_stale_node(node_file)
                throw(:connection_failed)
            end
          end

          # Try to connect to daemon
          Node.set_cookie(:el)

          task = Task.async(fn -> Node.connect(node_name) end)

          case Task.yield(task, 2000) || Task.shutdown(task) do
            {:ok, true} ->
              {:ok, node_name}

            {:ok, :ignored} ->
              {:ok, node_name}

            _ ->
              cleanup_stale_node(node_file)
              :not_found
          end
        catch
          :connection_failed ->
            :not_found

          _, _ ->
            cleanup_stale_node(node_file)
            :not_found
        end

      {:error, :enoent} ->
        :not_found
    end
  end

  defp cleanup_stale_node(node_file) do
    File.rm(node_file)
  rescue
    _ -> :ok
  end

  defp write_daemon_node do
    node_file = Path.expand("~/.el/daemon_node")
    File.mkdir_p!(Path.dirname(node_file))
    File.write!(node_file, Atom.to_string(Node.self()))
  end

  defp spawn_daemon(name) do
    binary_path = get_binary_path()

    cmd = ~c"nohup #{binary_path} --daemon #{name} > /dev/null 2>&1 &"
    :os.cmd(cmd)

    case poll_daemon_ready(300) do
      :ok ->
        IO.puts("el: #{name} is up")

      :timeout ->
        IO.puts(:stderr, "el: daemon startup timeout")
        System.halt(1)
    end
  end

  defp get_binary_path do
    burrito_bin = System.get_env("__BURRITO_BIN_PATH")

    if burrito_bin && burrito_bin != "" do
      burrito_bin
    else
      :escript.script_name() |> to_string()
    end
  end

  defp poll_daemon_ready(retries_left) when retries_left <= 0 do
    :timeout
  end

  defp poll_daemon_ready(retries_left) do
    case find_daemon_node() do
      {:ok, daemon_node} ->
        case :rpc.call(daemon_node, El, :local_ls, []) do
          {:badrpc, _reason} ->
            :timer.sleep(100)
            poll_daemon_ready(retries_left - 1)

          _result ->
            :ok
        end

      :not_found ->
        :timer.sleep(100)
        poll_daemon_ready(retries_left - 1)
    end
  end

  defp retry_start_node(retries_left) when retries_left <= 0 do
    IO.puts(:stderr, "FATAL: Cannot start el@127.0.0.1 after retries")
    System.halt(1)
  end

  defp retry_start_node(retries_left) do
    delay_ms = (6 - retries_left) * 100
    :timer.sleep(delay_ms)

    case Node.start(:"el@127.0.0.1") do
      {:ok, _} ->
        Node.set_cookie(:el)

        case Application.ensure_all_started(:el) do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
        end

        write_daemon_node()
        Node.self()

      {:error, _reason} ->
        retry_start_node(retries_left - 1)
    end
  end
end
