defmodule El.Deps.Spec do
  use ExUnit.Case

  describe "El.Deps.production/0" do
    test "returns map with init_module key defaulting to El.MessageStore.Init" do
      result = El.Deps.production()

      assert is_list(result)
      assert Keyword.has_key?(result, :init_module)
      assert Keyword.get(result, :init_module) == El.MessageStore.Init
    end
  end
end
