defmodule El.Infra.FileSystem.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.Infra.FileSystem)
    Code.ensure_loaded!(El.Infra.Behaviours.FileSystem)
    :ok
  end

  describe "El.Infra.FileSystem" do
    test "declares @behaviour El.Infra.Behaviours.FileSystem" do
      assert El.Infra.Behaviours.FileSystem in El.Infra.FileSystem.module_info(:attributes)[:behaviour] ||
             []
    end

    test "implements FileSystem.mkdir_p!/1" do
      assert function_exported?(El.Infra.FileSystem, :mkdir_p!, 1)
    end
  end
end
