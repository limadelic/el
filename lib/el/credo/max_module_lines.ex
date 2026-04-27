defmodule El.Credo.MaxModuleLines do
  use Credo.Check, category: :refactor, base_priority: :normal

  alias Credo.SourceFile
  alias Credo.Code
  alias El.Credo.LineCheck

  def param_defaults do
    [max_lines: 100]
  end

  def explanations do
    [
      check: "Modules should be reasonably sized and focused.",
      params: [
        max_lines: "The maximum number of lines a module body can have."
      ]
    ]
  end

  def run(%SourceFile{} = source_file, params) do
    max_lines = Keyword.get(params, :max_lines, 100)
    Code.prewalk(source_file, &check_module(&1, &2, max_lines))
  end

  defp check_module({:defmodule, meta, [_head | _tail]} = ast, issues, max_lines) do
    {ast, maybe_add_issue(max_lines, meta, issues)}
  end

  defp check_module(ast, issues, _max_lines) do
    {ast, issues}
  end

  defp maybe_add_issue(max_lines, meta, issues) do
    case LineCheck.find_body_lines(meta) do
      {:ok, body_lines} -> add_if_over_limit(body_lines, max_lines, meta, issues)
      :error -> issues
    end
  end

  defp add_if_over_limit(body_lines, max_lines, meta, issues) do
    if body_lines > max_lines do
      [create_issue(body_lines, max_lines, meta) | issues]
    else
      issues
    end
  end

  defp create_issue(body_lines, max_lines, meta) do
    LineCheck.issue_for(__MODULE__, "Module", body_lines, max_lines, meta)
  end
end
