defmodule El.Credo.FolderSize do
  use Credo.Check, category: :refactor, base_priority: :normal, run_on_all: true

  alias Credo.SourceFile
  alias Credo.Check.Params
  alias Credo.IssueMeta

  def param_defaults do
    [max: 13]
  end

  @check_desc "Folder structure is maintainable."

  def explanations do
    [
      check: @check_desc,
      params: [
        max: "Maximum .ex files allowed in a folder (default 13)"
      ]
    ]
  end

  def run(%SourceFile{} = _source_file, _params) do
    []
  end

  def run_on_all_source_files(exec, source_files, params) do
    max = Params.get(params, :max, __MODULE__)
    source_files
    |> Enum.group_by(fn sf -> Path.dirname(sf.filename) end)
    |> Enum.each(fn {folder, files} ->
      if length(files) > max do
        sf = hd(files)
        issue_meta = IssueMeta.for(sf, params)
        issue = format_issue(issue_meta,
          message: "Folder #{folder} has #{length(files)} .ex files (max: #{max})",
          line_no: 1
        )
        Credo.Execution.ExecutionIssues.append(exec, sf, issue)
      end
    end)
    :ok
  end
end
