defmodule El.MessageStore.Facade do
  def delete_session_messages(name, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.delete(name)
  end
end
