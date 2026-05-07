defmodule El.Session.Registry do
  def via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end

  def alive?(name) do
    match?([{_pid, _}], Registry.lookup(El.Registry, name))
  end

  def list(opts) do
    El.Deps.registry(opts).select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end
end
