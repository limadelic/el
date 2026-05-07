defmodule El.MessageStore.Behaviours.Store do
  @callback delete_ask_entry(term(), term(), term()) :: term()
  @callback store_ask_entry(term(), term()) :: term()
  @callback replace_ask(term(), term(), term(), term(), term()) :: term()
  @callback delete_message(term(), term()) :: term()
  @callback delete_message(term(), term(), keyword()) :: term()
  @callback store_message(term(), term()) :: term()
  @callback store_message(term(), term(), keyword()) :: term()
  @callback delete_session_messages(term()) :: term()
  @callback delete_session_messages(term(), keyword()) :: term()
  @callback load_messages(term()) :: term()
  @callback load_messages(term(), keyword()) :: term()
end
