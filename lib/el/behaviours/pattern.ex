defmodule El.Behaviours.Pattern do
  @callback restart(term(), term()) :: term()
  @callback exit(term(), term()) :: term()
  @callback clear(term(), term()) :: term()
  @callback log(term(), term(), term()) :: term()
end
