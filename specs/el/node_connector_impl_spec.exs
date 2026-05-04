defmodule El.NodeConnectorImpl.Spec do
  use ExUnit.Case

  describe "El.NodeConnectorImpl" do
    test "declares @behaviour El.Behaviours.NodeConnector" do
      assert El.Behaviours.NodeConnector in El.NodeConnectorImpl.module_info(:attributes)[:behaviour] ||
             []
    end
  end
end
