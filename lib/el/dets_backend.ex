defmodule El.DetsBackend do
  def insert(table, key_entry) do
    :dets.insert(table, key_entry)
  end

  def lookup(table, key) do
    :dets.lookup(table, key)
  end

  def delete_object(table, key_entry) do
    :dets.delete_object(table, key_entry)
  end

  def delete(table, key) do
    :dets.delete(table, key)
  end

  def foldl(table, acc, fun) do
    :dets.foldl(fun, acc, table)
  end
end
