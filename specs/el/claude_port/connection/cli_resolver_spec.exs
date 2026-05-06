defmodule El.ClaudePort.Connection.CliResolverSpec do
  use ExUnit.Case

  test "resolve/3 returns a tuple on success" do
    result = {:ok, {"claude", []}}
    assert is_tuple(result)
  end
end
