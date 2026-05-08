defmodule El.Credo.FolderSize.Spec do
  use ExUnit.Case

  setup_all do
    Code.require_file("credo_checks/folder_size.ex")
    :ok
  end

  defp make_source_files(filenames) do
    Enum.map(filenames, fn filename ->
      %Credo.SourceFile{filename: filename}
    end)
  end

  test "14 files in same folder → expect 1 issue" do
    files =
      Enum.map(1..14, fn i ->
        "lib/foo/file#{i}.ex"
      end)
      |> make_source_files()

    result = El.Credo.FolderSize.run_on_all_source_files(nil, files, max: 13)
    assert length(result) == 1
    assert Enum.any?(result, fn issue ->
      String.contains?(issue.message, "lib/foo")
    end)
  end

  test "13 files in same folder → expect 0 issues" do
    files =
      Enum.map(1..13, fn i ->
        "lib/foo/file#{i}.ex"
      end)
      |> make_source_files()

    result = El.Credo.FolderSize.run_on_all_source_files(nil, files, max: 13)
    assert result == []
  end

  test "spread across 2 folders under limit → expect 0 issues" do
    files =
      (Enum.map(1..7, fn i -> "lib/foo/file#{i}.ex" end) ++
         Enum.map(1..7, fn i -> "lib/bar/file#{i}.ex" end))
      |> make_source_files()

    result = El.Credo.FolderSize.run_on_all_source_files(nil, files, max: 13)
    assert result == []
  end
end
