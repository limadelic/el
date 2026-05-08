defmodule El.Credo.FolderSize.Spec do
  use ExUnit.Case

  setup_all do
    Code.require_file("credo_checks/folder_size.ex")
    :ok
  end

  test "returns empty list for source file" do
    source_file = %Credo.SourceFile{filename: "test.ex"}

    result = El.Credo.FolderSize.run(source_file, [])
    assert result == []
  end
end
