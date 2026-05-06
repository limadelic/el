defmodule El.Infra.FileSystem.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.Infra.FileSystem)
    Code.ensure_loaded!(El.Behaviours.FileSystem)
    :ok
  end

  describe "El.Infra.FileSystem" do
    test "declares @behaviour El.Behaviours.FileSystem" do
      assert El.Behaviours.FileSystem in El.Infra.FileSystem.module_info(:attributes)[:behaviour] ||
             []
    end

    test "implements FileSystem.mkdir_p!/1" do
      assert function_exported?(El.Infra.FileSystem, :mkdir_p!, 1)
    end
  end
end
