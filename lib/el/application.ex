defmodule El.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    result = Supervisor.start_link(children(), supervisor_opts())

    if System.get_env("__BURRITO") do
      spawn(fn ->
        try do
          args = Burrito.Util.Args.argv()
          El.CLI.main(args)
          System.halt(0)
        catch
          _kind, _reason -> :ok
        end
      end)
    end

    result
  end

  def children do
    [
      {Registry, keys: :unique, name: El.Registry},
      {DynamicSupervisor, name: El.SessionSupervisor}
    ]
  end

  def supervisor_opts do
    [strategy: :one_for_one, name: El.Supervisor]
  end
end
