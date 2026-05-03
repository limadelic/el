defmodule El.Behaviours.SessionAsk do
  @callback prepare_ask(state :: map(), from :: any(), message :: any()) :: {reference(), map()}
  @callback spawn_ask(state :: map(), ask_info :: any(), routes :: list(), server_pid :: pid()) :: any()
  @callback finalize_ask(state :: map(), from :: any(), ref :: reference(), message :: any(), response :: any(), model :: any()) :: map()
  @callback reset_session(state :: map()) :: map()
end
