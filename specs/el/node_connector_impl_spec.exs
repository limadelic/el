defmodule El.NodeConnectorImpl.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.NodeConnectorImpl)
    Code.ensure_loaded!(El.Behaviours.NodeConnector)
    :ok
  end

  describe "El.NodeConnectorImpl" do
    test "declares @behaviour El.Behaviours.NodeConnector" do
      assert El.Behaviours.NodeConnector in El.NodeConnectorImpl.module_info(:attributes)[:behaviour] ||
             []
    end
  end
end
