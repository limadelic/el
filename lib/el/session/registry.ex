defmodule El.Session.Registry do
  @behaviour El.Session.Behaviours.Registry

  def via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end

  def alive?(name) do
    match?([{_pid, _}], Registry.lookup(El.Registry, name))
  end

  @impl true
  def list(opts) do
    registry_impl(opts).select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end

  defp registry_impl(opts) do
    Keyword.get(opts, :registry, Application.get_env(:el, :registry, Registry))
  end
end
