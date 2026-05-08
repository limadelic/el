defmodule El.ClaudePort.State.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.ClaudePort.State)
    Code.ensure_loaded!(El.Infra.Behaviours.FileSystem)
    :ok
  end

  setup :verify_on_exit!

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

  describe "El.ClaudePort.State.build cwd routing" do
    test "gets cwd from mocked FileSystem when cwd not provided" do
      Application.put_env(:el, :fs_module, El.MockFileSystem)
      on_exit(fn -> Application.delete_env(:el, :fs_module) end)
      expect(El.MockFileSystem, :cwd!, fn -> "/mocked/cwd" end)

      state = El.ClaudePort.State.build([])

      assert state.cwd == "/mocked/cwd"
    end

    test "uses provided cwd instead of calling fs_module" do
      state = El.ClaudePort.State.build(cwd: "/provided/cwd")

      assert state.cwd == "/provided/cwd"
    end

    test "uses default FileSystem when fs_module not configured" do
      state = El.ClaudePort.State.build([])

      assert is_binary(state.cwd)
    end
  end
end
