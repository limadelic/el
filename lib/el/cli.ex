defmodule El.CLI do
  def main(args) do
    main_impl(args)
  end

  defp main_impl([]) do
    IO.puts("usage: el ls | el <name> [&] | el <name> tell <message> | el <name> ask <message> | el <name> log | el <name> kill")
  end

  defp main_impl(["ls"]) do
    daemon_node = ensure_node()

    sessions = if daemon_node && daemon_node != Node.self() do
      # RPC to daemon node to get sessions
      :rpc.call(daemon_node, El, :local_ls, [])
    else
      # Local query
      El.ls()
    end

    sessions
    |> Enum.each(fn name ->
      if session_alive?(name, daemon_node) do
        IO.puts(Atom.to_string(name))
      else
        IO.puts("(#{name})")
      end
    end)
  end

  defp main_impl([name]) do
    ensure_node()
    El.start(String.to_atom(name))
    # Check if stdin is a TTY (interactive) or not (backgrounded/headless)
    if is_tty?() do
      # Interactive: run PTY
      case catch_exit(fn -> El.PTY.run(String.to_atom(name)) end) do
        :ok -> :ok
        _ -> run_as_zombie(name)
      end
    else
      # Backgrounded/headless: run as zombie daemon
      run_as_zombie(name)
    end
  end

  defp main_impl([name, "&"]) do
    ensure_node()
    El.start(String.to_atom(name))
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
    ensure_node()
    msg = Enum.join(words, " ")
    response = El.tell(String.to_atom(name), msg)
    IO.write(response)
  end

  defp main_impl([name, "ask" | words]) do
    ensure_node()
    msg = Enum.join(words, " ")
    response = El.ask(String.to_atom(name), msg)
    IO.write(response)
  end

  defp main_impl([name, "log"]) do
    ensure_node()
    El.log(String.to_atom(name))
    |> Enum.each(fn {type, message, response} ->
      IO.puts("[#{type}] #{message}")
      IO.puts(response)
    end)
  end

  defp main_impl([name, "kill"]) do
    daemon_node = ensure_node()
    name_atom = String.to_atom(name)

    if daemon_node && daemon_node != Node.self() do
      :rpc.call(daemon_node, El, :kill, [name_atom])
    else
      El.kill(name_atom)
    end
  end

  defp main_impl(_) do
    main_impl([])
  end

  defp ensure_node do
    if Node.alive?() do
      case read_daemon_node() do
        {:ok, node} -> node
        :not_found -> Node.self()
      end
    else
      # Not alive yet — try to connect to existing daemon or start new one
      case try_connect_daemon() do
        {:ok, daemon_node} ->
          # Successfully connected to existing daemon
          {:ok, _} = Application.ensure_all_started(:el)
          daemon_node

        :not_found ->
          # No daemon found — try to start one
          # First, try to connect to el@127.0.0.1 in case it's running but file is missing
          Node.set_cookie(:el)
          case Node.connect(:"el@127.0.0.1") do
            true ->
              # Successfully connected to existing daemon
              {:ok, _} = Application.ensure_all_started(:el)
              write_daemon_node()
              :"el@127.0.0.1"

            :ignored ->
              # Already connected (this is the daemon)
              {:ok, _} = Application.ensure_all_started(:el)
              write_daemon_node()
              Node.self()

            false ->
              # Not connected — try to start our own daemon node
              case Node.start(:"el@127.0.0.1") do
                {:ok, _} ->
                  # New node started successfully
                  Node.set_cookie(:el)
                  {:ok, _} = Application.ensure_all_started(:el)
                  write_daemon_node()
                  Node.self()

                {:error, {:already_started, _}} ->
                  # Node is already started in this VM (we are the daemon)
                  Node.set_cookie(:el)
                  {:ok, _} = Application.ensure_all_started(:el)
                  write_daemon_node()
                  Node.self()

                {:error, reason} ->
                  IO.puts(:stderr, "FATAL: Cannot start daemon node el@127.0.0.1: #{inspect(reason)}")
                  IO.puts(:stderr, "This usually means the port 4369 (epmd) is in use or another Erlang VM is running.")
                  System.halt(1)
              end
          end
      end
    end
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
