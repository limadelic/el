defmodule El.Credo.FolderSize do
  use Credo.Check, category: :refactor, base_priority: :normal, run_on_all: true

  alias Credo.SourceFile
  alias Credo.Issue

  def param_defaults do
    [max: 13]
  end

  @check_desc "Folder structure is maintainable."
  @param_desc "Maximum number of .ex files per folder"

  def explanations do
    [check: @check_desc, params: [max: @param_desc]]
  end

  def run_on_all_source_files(_exec, source_files, params) do
    max = Keyword.get(params, :max, 13)
    source_files
    |> group_by_folder()
    |> Enum.flat_map(&check_folder(&1, max))
  end

  defp group_by_folder(source_files) do
    source_files
    |> Enum.map(fn %SourceFile{filename: filename} ->
      {Path.dirname(filename), filename}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp check_folder({_folder, []}, _max) do
    []
  end

  defp check_folder({folder, files}, max) when length(files) > max do
    count = length(files)
    message = "#{folder} has #{count} .ex files (max: #{max})"
    [%Issue{
      check: __MODULE__,
      message: message,
      category: :refactor,
      exit_status: 2,
      priority: :normal
    }]
  end

  defp check_folder({_folder, _files}, _max) do
    []
  end
end
