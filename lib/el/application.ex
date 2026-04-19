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

    if System.get_env("RELEASE_NAME") do
      spawn(fn ->
        try do
          args = Burrito.Util.Args.argv()
          El.CLI.main(args)
          System.halt(0)
        catch
          _kind, reason ->
            IO.puts(:stderr, "el: #{inspect(reason)}")
            System.halt(1)
        end
      end)
    end

    result
  end
end
