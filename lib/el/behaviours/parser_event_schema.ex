defmodule El.Behaviours.ParserEventSchema do
  @callback is_result_message(map()) :: boolean()
  @callback has_model(map()) :: boolean()
  @callback has_session_id(map()) :: boolean()
  @callback get_result(map()) :: any()
  @callback get_model(map()) :: String.t() | nil
  @callback get_session_id(map()) :: String.t() | nil
end
