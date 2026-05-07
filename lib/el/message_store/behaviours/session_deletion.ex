defmodule El.MessageStore.Behaviours.SessionDeletion do
  @callback delete_session_messages(term()) :: term()
  @callback delete_session_messages(term(), keyword()) :: term()
end
