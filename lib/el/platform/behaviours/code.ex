defmodule El.Platform.Behaviours.Code do
  @callback stream(term(), term()) :: term()
  @callback stream(term(), term(), list()) :: term()
end
