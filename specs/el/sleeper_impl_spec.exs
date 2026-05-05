defmodule El.SleeperImpl.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.SleeperImpl)
    Code.ensure_loaded!(El.Behaviours.Sleeper)
    :ok
  end

  describe "El.SleeperImpl" do
    test "declares @behaviour El.Behaviours.Sleeper" do
      assert El.Behaviours.Sleeper in El.SleeperImpl.module_info(:attributes)[:behaviour] ||
             []
    end
  end
end
