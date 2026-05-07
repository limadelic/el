defmodule El.Infra.Behaviours.JSONDecoder do
  @callback decode(String.t()) :: {:ok, term()} | {:error, term()}
end
