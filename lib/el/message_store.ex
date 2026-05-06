defmodule El.MessageStore do
  @behaviour El.MessageStore.Behaviours.MessageStore

  def delete(name, deps \\ []) do
    backend = dets_backend(deps)
    backend.delete(:message_store, name)
    :ok
  end

  def delete_entry(name, entry, deps \\ []) do
    backend = dets_backend(deps)
    backend.delete_object(:message_store, {name, entry})
    :ok
  end

  def insert(name, message_entry, deps \\ []) do
    backend = dets_backend(deps)
    backend.insert(:message_store, {name, message_entry})
    :ok
  end

  def lookup(name, deps \\ []) do
    backend = dets_backend(deps)
    backend.lookup(:message_store, name) |> Enum.map(fn {_key, entry} -> entry end)
  end

  def session_names(deps \\ []) do
    backend = dets_backend(deps)
    backend.foldl(:message_store, MapSet.new(), &add_session_name/2) |> MapSet.to_list()
  end

  def close(deps \\ []) do
    backend = dets_backend(deps)
    backend.close(:message_store)
  end

  defp add_session_name({name, _}, acc), do: MapSet.put(acc, name)

  defp dets_backend(deps), do: Keyword.get(deps, :dets_backend, El.DetsBackend)
end
