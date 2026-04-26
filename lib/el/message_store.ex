defmodule El.MessageStore do
  def delete(name) do
    :dets.delete(:message_store, name)
    :ok
  end

  def delete_entry(name, entry) do
    :dets.delete_object(:message_store, {name, entry})
    :ok
  end

  def insert(name, message_entry) do
    :dets.insert(:message_store, {name, message_entry})
    :ok
  end

  def lookup(name) do
    :dets.lookup(:message_store, name)
    |> Enum.map(fn {_key, entry} -> entry end)
  end
end
