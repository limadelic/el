defmodule El.Behaviours.Port do
  @callback open(term(), term()) :: {:ok, term()} | {:error, term()}
  @callback command(term(), term()) :: term()
  @callback info(term()) :: term()
  @callback close(term()) :: term()
end
