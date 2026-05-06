defmodule El.CLI.Daemon.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon)
    Code.ensure_loaded!(El.Infra.Behaviours.System)
    Code.ensure_loaded!(El.Infra.Behaviours.NodeConnector)
    Code.ensure_loaded!(El.Infra.Behaviours.NetKernel)
    Code.ensure_loaded!(El.Infra.System)
    Code.ensure_loaded!(El.Infra.NodeConnector)
    Code.ensure_loaded!(El.Infra.NetKernel)
    :ok
  end

  setup :verify_on_exit!

  describe "El.Infra.System" do
    test "declares @behaviour El.Infra.Behaviours.System" do
      assert El.Infra.Behaviours.System in El.Infra.System.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.Infra.NodeConnector" do
    test "declares @behaviour El.Infra.Behaviours.NodeConnector" do
      assert El.Infra.Behaviours.NodeConnector in El.Infra.NodeConnector.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.Infra.NetKernel" do
    test "declares @behaviour El.Infra.Behaviours.NetKernel" do
      assert El.Infra.Behaviours.NetKernel in El.Infra.NetKernel.module_info(:attributes)[:behaviour] || []
    end
  end
end
