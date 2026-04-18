defmodule El.CLI do
  def main([]) do
    IO.puts("usage: el ls | el <name> [&] | el <name> tell <message> | el <name> ask <message> | el <name> log | el <name> kill")
  end

  def main(["ls"]) do
    ensure_node()
    El.ls()
    |> Enum.each(fn name ->
      if El.Session.alive?(name) do
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
    unless Node.alive?() do
      {:ok, _} = Node.start(:"el@127.0.0.1")
      Node.set_cookie(:el)
      {:ok, _} = Application.ensure_all_started(:el)
    end
  end
end
