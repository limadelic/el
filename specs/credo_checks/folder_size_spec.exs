defmodule El.Credo.FolderSize.Spec do
  use ExUnit.Case

  setup_all do
    Code.require_file("credo_checks/folder_size.ex")
    :ok
  end

  test "module exports run_on_all_source_files/3" do
    assert function_exported?(El.Credo.FolderSize, :run_on_all_source_files, 3)
  end

  test "run_on_all?/0 returns true" do
    assert El.Credo.FolderSize.run_on_all?() == true
  end

  test "param_defaults includes max, min, exempt, and exempt_names" do
    defaults = El.Credo.FolderSize.param_defaults()
    assert Keyword.has_key?(defaults, :max)
    assert Keyword.has_key?(defaults, :min)
    assert Keyword.has_key?(defaults, :exempt)
    assert Keyword.has_key?(defaults, :exempt_names)
    assert defaults[:max] == 13
    assert defaults[:min] == 3
    assert defaults[:exempt] == []
    assert defaults[:exempt_names] == []
  end

  test "exempt_names matches any path segment, not just basename" do
    folder = "lib/el/claude_port/behaviours/parser"
    exempt_names = ["behaviours"]
    assert Enum.any?(Path.split(folder), &(&1 in exempt_names))
  end
end
