defmodule El.Credo.FolderSize do
  use Credo.Check, category: :refactor, base_priority: :normal

  alias Credo.SourceFile

  def param_defaults do
    []
  end

  @check_desc "Folder structure is maintainable."

  def explanations do
    [check: @check_desc, params: []]
  end

  def run(%SourceFile{} = _source_file, _params) do
    []
  end
end
