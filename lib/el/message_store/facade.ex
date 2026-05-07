defmodule El.MessageStore.Facade do
  @behaviour El.MessageStore.Behaviours.SessionDeletion

  @impl true
  def delete_session_messages(name, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.delete(name)
  end

  def store_message(name, message_entry, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.insert(name, message_entry)
  end

  def load_messages(name, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.lookup(name)
  end

  def delete_message(name, entry, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.delete_entry(name, entry)
  end
end
