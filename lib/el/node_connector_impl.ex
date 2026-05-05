defmodule El.NodeConnectorImpl do
  @behaviour El.Behaviours.NodeConnector

  @impl true
  def connect(node) do
    Node.connect(node)
  end

  @impl true
  def set_cookie(cookie) do
    Node.set_cookie(cookie)
  end
end
