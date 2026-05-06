defmodule El.Behaviours.ClaudePortCliResolver do
  @callback resolve(atom() | String.t(), keyword(), String.t() | nil) ::
              {:ok, {String.t(), [String.t()]}} | {:error, term()}
end
