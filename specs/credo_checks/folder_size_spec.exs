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

  test "param_defaults includes both max and min" do
    defaults = El.Credo.FolderSize.param_defaults()
    assert Keyword.has_key?(defaults, :max)
    assert Keyword.has_key?(defaults, :min)
    assert defaults[:max] == 13
    assert defaults[:min] == 3
  end
end
