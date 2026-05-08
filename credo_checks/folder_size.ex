defmodule El.Credo.FolderSize do
  use Credo.Check, category: :refactor, base_priority: :normal, run_on_all: true

  alias Credo.SourceFile
  alias Credo.Check.Params
  alias Credo.IssueMeta

  def param_defaults do
    [max: 13, min: 3, exempt: [], exempt_names: []]
  end

  @check_desc "Folder structure is maintainable."

  def explanations do
    [
      check: @check_desc,
      params: [
        max: "Maximum .ex files allowed in a folder (default 13)",
        min: "Minimum .ex files required in a folder (default 3)",
        exempt: "List of folder paths to skip (default [])",
        exempt_names: "List of folder names to skip (default [])"
      ]
    ]
  end

  def run(%SourceFile{} = _source_file, _params) do
    []
  end

  def run_on_all_source_files(exec, source_files, params) do
    max = Params.get(params, :max, __MODULE__)
    min = Params.get(params, :min, __MODULE__)
    exempt = Params.get(params, :exempt, __MODULE__)
    exempt_names = Params.get(params, :exempt_names, __MODULE__)
    source_files
    |> Enum.group_by(fn sf -> Path.dirname(sf.filename) end)
    |> Enum.each(fn {folder, files} ->
      skip? = folder in exempt or Enum.any?(Path.split(folder), &(&1 in exempt_names))
      unless skip? do
        sf = hd(files)
        issue_meta = IssueMeta.for(sf, params)
        file_count = length(files)

        if file_count > max do
          issue = format_issue(issue_meta,
            message: "Folder #{folder} has #{file_count} .ex files (max: #{max})",
            line_no: 1
          )
          Credo.Execution.ExecutionIssues.append(exec, sf, issue)
        end

        if file_count < min do
          issue = format_issue(issue_meta,
            message: "Folder #{folder} has #{file_count} .ex files (min: #{min})",
            line_no: 1
          )
          Credo.Execution.ExecutionIssues.append(exec, sf, issue)
        end
      end
    end)
    :ok
  end
end
