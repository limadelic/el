defmodule El.CLI.Daemon.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon)
    Code.ensure_loaded!(El.Behaviours.System)
    Code.ensure_loaded!(El.Behaviours.NodeConnector)
    Code.ensure_loaded!(El.Behaviours.NetKernel)
    Code.ensure_loaded!(El.SystemImpl)
    Code.ensure_loaded!(El.NodeConnectorImpl)
    Code.ensure_loaded!(El.NetKernelImpl)
    :ok
  end

  setup :verify_on_exit!

  describe "El.SystemImpl" do
    test "declares @behaviour El.Behaviours.System" do
      assert El.Behaviours.System in El.SystemImpl.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.NodeConnectorImpl" do
    test "declares @behaviour El.Behaviours.NodeConnector" do
      assert El.Behaviours.NodeConnector in El.NodeConnectorImpl.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.NetKernelImpl" do
    test "declares @behaviour El.Behaviours.NetKernel" do
      assert El.Behaviours.NetKernel in El.NetKernelImpl.module_info(:attributes)[:behaviour] || []
    end
  end
end
