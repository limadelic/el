defmodule El.Infra.GroupLeader.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.Infra.Behaviours.GroupLeader)
    Code.ensure_loaded!(El.Infra.GroupLeader)
    :ok
  end

  setup :verify_on_exit!

  describe "El.Infra.GroupLeader" do
    test "declares @behaviour El.Behaviours.GroupLeader" do
      assert El.Infra.Behaviours.GroupLeader in El.Infra.GroupLeader.module_info(:attributes)[:behaviour] || []
    end
  end
end
