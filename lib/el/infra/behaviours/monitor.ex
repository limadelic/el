defmodule El.Infra.Behaviours.Monitor do
  @callback wait_for_down(term(), term()) :: term()
  @callback wait_for_down(term(), term(), keyword()) :: term()
end
