defmodule El.ClaudePort.Connection.CliResolverSpec do
  use ExUnit.Case
  import Mox
  setup :verify_on_exit!

  test "resolve/3 returns ok with binary executable" do
    result = El.ClaudePort.Connection.CliResolver.resolve("/path/to/cli", [], "resume-123")
    assert match?({:ok, {executable, _args}} when is_binary(executable), result)
  end

  test "resolve/3 returns ok with list of args" do
    result = El.ClaudePort.Connection.CliResolver.resolve("/path/to/cli", [], "resume-123")
    assert match?({:ok, {_executable, args}} when is_list(args), result)
  end
end
