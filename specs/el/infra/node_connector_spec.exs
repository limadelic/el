defmodule El.Infra.NodeConnector.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.Infra.NodeConnector)
    Code.ensure_loaded!(El.Behaviours.NodeConnector)
    :ok
  end

  describe "El.Infra.NodeConnector" do
    test "declares @behaviour El.Behaviours.NodeConnector" do
      assert El.Behaviours.NodeConnector in El.Infra.NodeConnector.module_info(:attributes)[:behaviour] ||
             []
    end
  end
end
