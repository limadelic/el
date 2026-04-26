defmodule El.MessageStore do
  def delete(name) do
    backend = Application.get_env(:el, :dets_backend, El.DetsBackend)
    backend.delete(:message_store, name)
    :ok
  end

  def delete_entry(name, entry) do
    backend = Application.get_env(:el, :dets_backend, El.DetsBackend)
    backend.delete_object(:message_store, {name, entry})
    :ok
  end

  def insert(name, message_entry) do
    backend = Application.get_env(:el, :dets_backend, El.DetsBackend)
    backend.insert(:message_store, {name, message_entry})
    :ok
  end

  def lookup(name) do
    backend = Application.get_env(:el, :dets_backend, El.DetsBackend)
    backend.lookup(:message_store, name)
    |> Enum.map(fn {_key, entry} -> entry end)
  end
end
