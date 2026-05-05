defmodule El.GroupLeaderImpl.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.Behaviours.GroupLeader)
    Code.ensure_loaded!(El.GroupLeaderImpl)
    :ok
  end

  setup :verify_on_exit!

  describe "El.GroupLeaderImpl" do
    test "declares @behaviour El.Behaviours.GroupLeader" do
      assert El.Behaviours.GroupLeader in El.GroupLeaderImpl.module_info(:attributes)[:behaviour] || []
    end
  end
end
