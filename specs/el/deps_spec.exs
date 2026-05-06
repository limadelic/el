defmodule El.Deps.Spec do
  use ExUnit.Case

  describe "El.Deps.production/0" do
    test "returns map with init_module key defaulting to El.MessageStore.Init" do
      result = El.Deps.production()

      assert Keyword.get(result, :init_module) == El.MessageStore.Init
    end

    test "returns map with restorer_module key defaulting to El.SessionRestorer" do
      result = El.Deps.production()

      assert Keyword.get(result, :restorer_module) == El.SessionRestorer
    end

    test "returns map with connection_module key defaulting to El.ClaudePort.Connection" do
      result = El.Deps.production()

      assert Keyword.get(result, :connection_module) == El.ClaudePort.Connection
    end
  end
end
