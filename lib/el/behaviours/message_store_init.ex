defmodule El.Behaviours.MessageStoreInit do
  @callback init_message_store(keyword()) :: :ok | {:ok, term()}
  @callback message_store_opts() :: keyword()
end
