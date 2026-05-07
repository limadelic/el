defmodule El.Session.Registry do
  def via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end

  def alive?(name) do
    match?([{_pid, _}], Registry.lookup(El.Registry, name))
  end

  def list(opts) do
    session_registry_for(opts).list(opts)
  end

  defp session_registry_for(opts) do
    Keyword.get(opts, :session_registry, El.Session.Registry.Impl)
  end
end
