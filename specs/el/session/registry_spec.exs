defmodule El.Session.RegistrySpec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "list/1" do
    test "returns sorted list of session names" do
      expect(El.MockRegistry, :select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:zeta, :alpha, :beta]
      end)

      assert El.Session.Registry.list(registry: El.MockRegistry) == [:alpha, :beta, :zeta]
    end
  end
end
