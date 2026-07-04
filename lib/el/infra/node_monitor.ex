defmodule El.Infra.NodeMonitor do
  @behaviour El.Infra.Behaviours.NodeMonitor

  @impl true
  def list do
    Node.list()
  end
end
