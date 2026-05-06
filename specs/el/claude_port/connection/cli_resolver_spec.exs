defmodule El.ClaudePort.Connection.CliResolverSpec do
  use ExUnit.Case

  setup do
    Mox.stub(ClaudeCode.Adapter.Port.Resolver, :find_binary, fn _opts ->
      {:ok, "/usr/local/bin/claude"}
    end)
    Mox.stub(ClaudeCode.CLI.Command, :build_args, fn _cmd, _opts, _resume_id ->
      ["--api-key", "test", "run", "quit"]
    end)
    :ok
  end

  test "resolve/3 calls Resolver.find_binary and returns executable and args" do
    result = El.ClaudePort.Connection.CliResolver.resolve("/path/to/cli", [], "resume-123")
    assert {:ok, {"/usr/local/bin/claude", ["--api-key", "test", "run"]}} = result
  end
end
