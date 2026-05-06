defmodule El.ClaudePort.Connection.CliResolverSpec do
  use ExUnit.Case
  import Mox
  setup :verify_on_exit!

  setup do
    {:ok, result: El.ClaudePort.Connection.CliResolver.resolve("/path/to/cli", [], "resume-123")}
  end

  test "resolve/3 returns ok with binary executable", %{result: result} do
    assert match?({:ok, {executable, _args}} when is_binary(executable), result)
  end

  test "resolve/3 returns ok with list of args", %{result: result} do
    assert match?({:ok, {_executable, args}} when is_list(args), result)
  end
end
