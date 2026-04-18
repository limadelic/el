defmodule El.CLI do
  def main(args) do
    main_impl(args)
  end

  defp main_impl([]) do
    IO.puts("usage: el ls | el <name> [&] | el <name> tell <message> | el <name> ask <message> | el <name> log | el <name> kill")
  end

  defp main_impl(["ls"]) do
    ensure_epmd()

    case find_daemon_node() do
      {:ok, daemon_node} ->
        :rpc.call(daemon_node, El, :local_ls, [])
        |> Enum.each(fn name ->
          if session_alive?(name, daemon_node) do
            IO.puts(Atom.to_string(name))
          else
            IO.puts("(#{name})")
          end
        end)
      :not_found ->
        IO.puts(:stderr, "Error: No daemon found. Start with: el <name> &")
        System.halt(1)
    end
  end

  defp main_impl([name]) do
    daemon_node = ensure_daemon_node()
    name_atom = String.to_atom(name)

    if daemon_node && daemon_node != Node.self() do
      # We're a client connecting to daemon
      :rpc.call(daemon_node, El, :start, [name_atom])
      # Check if stdin is a TTY (interactive) or not (backgrounded/headless)
      if is_tty?() do
        # Interactive: run PTY
        case catch_exit(fn -> El.PTY.run(name_atom) end) do
          :ok -> :ok
          _ -> run_as_zombie(name)
        end
      else
        # Backgrounded/headless: run as zombie daemon
        run_as_zombie(name)
      end
    else
      # We are the daemon
      El.start(name_atom)
      # Check if stdin is a TTY (interactive) or not (backgrounded/headless)
      if is_tty?() do
        # Interactive: run PTY
        case catch_exit(fn -> El.PTY.run(name_atom) end) do
          :ok -> :ok
          _ -> run_as_zombie(name)
        end
      else
        # Backgrounded/headless: run as zombie daemon
        run_as_zombie(name)
      end
    end
  end

  defp main_impl([name, "&"]) do
    daemon_node = ensure_daemon_node()
    name_atom = String.to_atom(name)

    if daemon_node && daemon_node != Node.self() do
      # We're a client connecting to daemon
      :rpc.call(daemon_node, El, :start, [name_atom])
    else
      # We are the daemon
      El.start(name_atom)
    end

    run_as_zombie(name)
  end

  defp catch_exit(fun) do
    try do
      fun.()
      :ok
    catch
      :exit, _ -> :error
    end
  end


  defp main_impl([name, "tell" | words]) do
    ensure_epmd()
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)

    case find_daemon_node() do
      {:ok, daemon_node} ->
        case :rpc.call(daemon_node, El, :tell, [name_atom, msg]) do
          {:badrpc, reason} ->
            IO.puts(:stderr, "Error: #{inspect(reason)}")
            System.halt(1)
          response ->
            IO.write(response)
        end
      :not_found ->
        IO.puts(:stderr, "Error: No daemon found. Start with: el #{name} &")
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
            IO.write(response)
        end
      :not_found ->
        IO.puts(:stderr, "Error: No daemon found. Start with: el #{name} &")
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
        IO.puts(:stderr, "Error: No daemon found. Start with: el #{name} &")
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
        IO.puts(:stderr, "Error: No daemon found. Start with: el #{name} &")
        System.halt(1)
    end
  end

  defp main_impl(_) do
    main_impl([])
  end

  defp ensure_daemon_node do
    ensure_epmd()

    if Node.alive?() do
      Node.self()
    else
      case Node.start(:"el@127.0.0.1") do
        {:ok, _} ->
          Node.set_cookie(:el)
          {:ok, _} = Application.ensure_all_started(:el)
          write_daemon_node()
          Node.self()

        {:error, {:already_started, _}} ->
          Node.set_cookie(:el)
          {:ok, _} = Application.ensure_all_started(:el)
          write_daemon_node()
          Node.self()

        {:error, _reason} ->
          nuke_epmd()
          case Node.start(:"el@127.0.0.1") do
            {:ok, _} ->
              Node.set_cookie(:el)
              {:ok, _} = Application.ensure_all_started(:el)
              write_daemon_node()
              Node.self()

            {:error, reason} ->
              IO.puts(:stderr, "FATAL: Cannot start daemon node el@127.0.0.1: #{inspect(reason)}")
              System.halt(1)
          end
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
    System.cmd("epmd", ["-daemon"], stderr_to_stdout: true)
    :timer.sleep(100)
  end

  defp nuke_epmd do
    System.cmd("pkill", ["-9", "beam.smp"], stderr_to_stdout: true)
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
            case Node.start(client_node) do
              {:ok, _} -> :ok
              {:error, {:already_started, _}} -> :ok
              {:error, _reason} ->
                cleanup_stale_node(node_file)
                throw :connection_failed
            end
          end

          # Try to connect to daemon
          Node.set_cookie(:el)
          case Node.connect(node_name) do
            true -> {:ok, node_name}
            false ->
              cleanup_stale_node(node_file)
              :not_found
            :ignored ->
              # Already connected or is self
              {:ok, node_name}
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

  defp session_alive?(name, daemon_node) do
    if daemon_node && daemon_node != Node.self() do
      # RPC to daemon node
      try do
        :rpc.call(daemon_node, El.Session, :alive?, [name]) == true
      catch
        :error, _ -> false
      end
    else
      El.Session.alive?(name)
    end
  end

  defp is_tty? do
    case :io.columns() do
      {:ok, _} -> true
      {:error, :enoent} -> false
      _ -> false
    end
  end

  defp run_as_zombie(name) do
    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end
end
