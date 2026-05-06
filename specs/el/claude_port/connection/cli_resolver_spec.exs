defmodule El.ClaudePort.Connection.CliResolverSpec do
  use ExUnit.Case

  test "resolve/3 returns ok tuple with executable and args" do
    result = El.ClaudePort.Connection.CliResolver.resolve("/path/to/cli", [], "resume-123")
    assert {:ok, {executable, args}} = result
    assert is_binary(executable)
    assert is_list(args)
  end
end
