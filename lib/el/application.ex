defmodule El.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    result = Supervisor.start_link(children(), supervisor_opts())
    spawn_burrito_if_enabled()
    result
  end

  defp spawn_burrito_if_enabled do
    do_spawn_if_enabled(burrito_enabled?())
  end

  defp do_spawn_if_enabled(true) do
    spawn(fn -> run_burrito_cli() end)
  end

  defp do_spawn_if_enabled(false) do
    :ok
  end

  defp burrito_enabled? do
    is_binary(System.get_env("__BURRITO"))
  end

  defp run_burrito_cli do
    safe_execute_burrito_cli()
  end

  defp safe_execute_burrito_cli do
    execute_burrito_cli()
  rescue
    _ -> :ok
  catch
    _kind, _reason -> :ok
  end

  defp execute_burrito_cli do
    args = Burrito.Util.Args.argv()
    El.CLI.main(args)
    System.halt(0)
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
