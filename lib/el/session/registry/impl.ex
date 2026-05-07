defmodule El.Session.Registry.Impl do
  @behaviour El.Session.Behaviours.Registry

  @impl true
  def list(opts) do
    El.Deps.registry(opts).select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end
end
