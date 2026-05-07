defmodule El.MessageStore.Behaviours.MessageStore do
  @callback delete(atom()) :: :ok
  @callback delete_entry(atom(), tuple()) :: :ok
  @callback insert(atom(), tuple()) :: :ok
  @callback lookup(atom()) :: list()
  @callback session_names() :: [atom()]
  @callback close() :: :ok
end
