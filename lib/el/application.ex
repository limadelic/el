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
      args = Burrito.Util.Args.argv()
      El.CLI.main(args)
      System.halt(0)
    end)

    result
  end
end
