defmodule El.Credo.FolderSizeSpec do
  use ExUnit.Case

  describe "FolderSize.run_on_all_source_files/3" do
    test "returns :ok for an empty source list" do
      result = El.Credo.FolderSize.run_on_all_source_files(nil, [], [])
      assert result == :ok
    end

    test "returns :ok with source files" do
      source_files = [
        %Credo.SourceFile{filename: "lib/test.ex"}
      ]
      result = El.Credo.FolderSize.run_on_all_source_files(nil, source_files, [])
      assert result == :ok
    end
  end
end
