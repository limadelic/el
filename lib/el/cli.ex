defmodule El.CLI do
  def main([name]) do
    {:ok, _} = Node.start(:"el_#{name}@127.0.0.1")
    Node.set_cookie(:el)
    {:ok, _} = Application.ensure_all_started(:el)
    El.PTY.run(String.to_atom(name))
  end

  def main(["tell", name | words]) do
    {:ok, _} = Node.start(:"el_client_#{System.os_time()}@127.0.0.1")
    Node.set_cookie(:el)
    target = :"el_#{name}@127.0.0.1"
    true = Node.connect(target)
    msg = Enum.join(words, " ")
    GenServer.cast({String.to_atom(name), target}, {:inject, msg <> "\r"})
  end

  def main(["headless", name]) do
    atom = String.to_atom(name)
    {:ok, _} = Node.start(:"el_#{name}@127.0.0.1")
    Node.set_cookie(:el)
    {:ok, _} = Application.ensure_all_started(:el)
    El.start(atom)
    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end

  def main(_) do
    IO.puts("usage: el <name> | el headless <name> | el tell <name> <message>")
  end
end
