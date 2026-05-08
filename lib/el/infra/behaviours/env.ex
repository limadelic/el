defmodule El.Infra.Behaviours.Env do
  @callback get() :: [{String.t(), String.t()}]
  @callback get(String.t()) :: String.t() | nil
end
