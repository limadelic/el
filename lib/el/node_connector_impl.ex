defmodule El.NodeConnectorImpl do
  @behaviour El.Behaviours.NodeConnector

  @impl true
  def connect(node) do
    Node.connect(node)
  end
end
