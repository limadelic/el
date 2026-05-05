defmodule El.FileSystemImpl.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.FileSystemImpl)
    Code.ensure_loaded!(El.Behaviours.FileSystem)
    :ok
  end

  describe "El.FileSystemImpl" do
    test "declares @behaviour El.Behaviours.FileSystem" do
      assert El.Behaviours.FileSystem in El.FileSystemImpl.module_info(:attributes)[:behaviour] ||
             []
    end

    test "implements FileSystem.mkdir_p!/1" do
      assert function_exported?(El.FileSystemImpl, :mkdir_p!, 1)
    end
  end
end
