defmodule El.Infra.Behaviours.NodeConnector do
  @callback connect(node()) :: boolean() | :ignored
  @callback set_cookie(atom()) :: true
end
