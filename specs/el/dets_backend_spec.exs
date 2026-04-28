defmodule El.DetsBackend.Spec do
  use ExUnit.Case

  describe "foldl/3" do
    test "module is defined" do
      assert Code.ensure_loaded?(El.DetsBackend)
    end

    test "exists with correct signature" do
      assert function_exported?(El.DetsBackend, :foldl, 3)
    end
  end
end
