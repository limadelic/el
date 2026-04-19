defmodule El.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: El.Registry},
      {DynamicSupervisor, name: El.SessionSupervisor},
      {El.SessionTracker, []}
    ]

    opts = [strategy: :one_for_one, name: El.Supervisor]
    result = Supervisor.start_link(children, opts)

    spawn(fn ->
      try do
        IO.puts(:stderr, "[el:debug] spawn started")
        args = Burrito.Util.Args.argv()
        IO.puts(:stderr, "[el:debug] args=#{inspect(args)}")
        El.CLI.main(args)
        IO.puts(:stderr, "[el:debug] CLI done, halting")
        System.halt(0)
      catch
        _kind, _reason -> :ok
      end
    end)

    result
  end
end
