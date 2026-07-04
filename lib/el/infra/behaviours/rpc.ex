defmodule El.Infra.Behaviours.RPC do
  @callback call(node(), atom(), atom(), list()) :: term()
end
