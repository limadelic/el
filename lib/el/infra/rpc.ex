defmodule El.Infra.RPC do
  @behaviour El.Infra.Behaviours.RPC

  @impl true
  def call(node, module, function, args) do
    :rpc.call(node, module, function, args)
  end
end
