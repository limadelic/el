defmodule El.CLI.Daemon.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Daemon)
    Code.ensure_loaded!(El.Behaviours.System)
    Code.ensure_loaded!(El.SystemImpl)
    :ok
  end

  setup :verify_on_exit!

  describe "El.SystemImpl" do
    test "declares @behaviour El.Behaviours.System" do
      assert El.Behaviours.System in El.SystemImpl.module_info(:attributes)[:behaviour] || []
    end
  end
end
