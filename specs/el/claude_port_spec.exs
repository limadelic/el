defmodule El.ClaudePort.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.ClaudePort)
    Code.ensure_loaded!(ClaudeCode.CLI.Parser)
    Code.ensure_loaded!(Jason)
    :ok
  end

  describe "init/1" do
    test "returns state with empty buffer" do
      {:ok, state, {:continue, :connect}} = El.ClaudePort.init(cwd: "/tmp")
      assert state.buffer == ""
    end
  end
end
