defmodule El.CLI do
  def main([]) do
    IO.puts("usage: el ls | el <name> [&] | el <name> tell <message> | el <name> ask <message> | el <name> log | el <name> kill")
  end

  def main(["ls"]) do
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

  def main([name]) do
    ensure_node()
    El.start(String.to_atom(name))
    # Try to run PTY if available, else fall back to daemon mode
    case catch_exit(fn -> El.PTY.run(String.to_atom(name)) end) do
      :ok -> :ok
      _ ->
        # PTY unavailable or failed, run as daemon
        IO.puts("el: #{name} is up on #{Node.self()}")
        Process.sleep(:infinity)
    end
  end

  defp catch_exit(fun) do
    try do
      fun.()
      :ok
    catch
      :exit, _ -> :error
    end
  end

  def main([name, "&"]) do
    ensure_node()
    El.start(String.to_atom(name))
    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end

  def main([name, "tell" | words]) do
    ensure_node()
    msg = Enum.join(words, " ")
    response = El.tell(String.to_atom(name), msg)
    IO.write(response)
  end

  def main([name, "ask" | words]) do
    ensure_node()
    msg = Enum.join(words, " ")
    response = El.ask(String.to_atom(name), msg)
    IO.write(response)
  end

  def main([name, "log"]) do
    ensure_node()
    El.log(String.to_atom(name))
    |> Enum.each(fn {type, message, response} ->
      IO.puts("[#{type}] #{message}")
      IO.puts(response)
    end)
  end

  def main([name, "kill"]) do
    ensure_node()
    El.kill(String.to_atom(name))
  end

  def main(_) do
    main([])
  end

  defp ensure_node do
    if Node.alive?() do
      case read_daemon_node() do
        {:ok, node} -> node
        :not_found -> Node.self()
      end
    else
      case try_connect_daemon() do
        {:ok, daemon_node} ->
          # Connected to existing daemon
          {:ok, _} = Application.ensure_all_started(:el)
          daemon_node

        :not_found ->
          # Start new daemon
          {:ok, _} = Node.start(:"el@127.0.0.1")
          Node.set_cookie(:el)
          {:ok, _} = Application.ensure_all_started(:el)
          write_daemon_node()
          Node.self()
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

        # Use unique name for this client node
        client_node = :"el_client_#{System.os_time()}@127.0.0.1"

        try do
          {:ok, _} = Node.start(client_node)
          Node.set_cookie(:el)

          if Node.connect(node_name) do
            {:ok, node_name}
          else
            cleanup_stale_node(node_file)
            :not_found
          end
        catch
          :error, _ ->
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
end
