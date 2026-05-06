defmodule El.ClaudePort.State.Spec do
  use ExUnit.Case

  describe "El.ClaudePort.State.build/1" do
    test "defaults connection_module to El.ClaudePort.Connection" do
      state = El.ClaudePort.State.build([])

      assert state.connection_module == El.ClaudePort.Connection
    end

    test "overrides connection_module from opts" do
      state = El.ClaudePort.State.build(connection_module: MockModule)

      assert state.connection_module == MockModule
    end

    test "defaults cli_resolver_module to El.ClaudePort.Connection.CliResolver" do
      state = El.ClaudePort.State.build([])

      assert state.cli_resolver_module == El.ClaudePort.Connection.CliResolver
    end
  end
end
