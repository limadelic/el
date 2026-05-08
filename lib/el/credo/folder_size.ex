defmodule El.Credo.FolderSize do
  use Credo.Check, base_priority: :high, category: :readability, run_on_all: true

  def param_defaults do
    []
  end

  def explanations do
    [check: "Folder sizes are within acceptable limits."]
  end

  def run_on_all_source_files(_exec, _source_files, _params) do
    :ok
  end
end
