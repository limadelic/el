defmodule El.RegistryReaderImpl do
  @behaviour El.Behaviours.RegistryReader

  @impl true
  def select(daemon_node) do
    :rpc.call(daemon_node, Registry, :select, [
      El.Registry,
      [{{:"$1", :_, :_}, [], [:"$1"]}]
    ])
  end
end
