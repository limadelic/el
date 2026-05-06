defmodule El.Infra.Sleeper.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.Infra.Sleeper)
    Code.ensure_loaded!(El.Behaviours.Sleeper)
    :ok
  end

  describe "El.Infra.Sleeper" do
    test "declares @behaviour El.Behaviours.Sleeper" do
      assert El.Behaviours.Sleeper in El.Infra.Sleeper.module_info(:attributes)[:behaviour] ||
             []
    end
  end
end
