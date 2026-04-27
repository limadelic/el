defmodule El.Credo.MaxModuleLines do
  use Credo.Check, category: :refactor, base_priority: :normal

  alias Credo.SourceFile
  alias Credo.Code

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
    max_lines = params |> Keyword.get(:max_lines, 100)

    Code.prewalk(source_file, &check_module(&1, &2, max_lines))
  end

  defp check_module({:defmodule, meta, [_head | _tail]} = ast, issues, max_lines) do
    result = check_lines(ast, max_lines, meta, issues)
    {ast, result}
  end

  defp check_module(ast, issues, _max_lines) do
    {ast, issues}
  end

  defp check_lines(ast, max_lines, meta, issues) do
    case find_module_body_lines(meta) do
      {:ok, body_lines} ->
        if body_lines > max_lines do
          issue = %Credo.Issue{
            check: El.Credo.MaxModuleLines,
            message: "Module body is too long (#{body_lines} lines, max is #{max_lines}).",
            filename: nil,
            line_no: meta[:line],
            column: meta[:column],
            trigger: module_name(ast),
            priority: priority(body_lines, max_lines),
            category: :refactor,
            exit_status: 2
          }

          [issue | issues]
        else
          issues
        end

      :error ->
        issues
    end
  end

  defp find_module_body_lines(meta) do
    end_line =
      case Keyword.fetch(meta, :end_line) do
        {:ok, line} -> line
        :error ->
          case Keyword.fetch(meta, :end_of_expression) do
            {:ok, expr_meta} -> Keyword.get(expr_meta, :line)
            :error -> nil
          end
      end

    case end_line do
      nil ->
        :error

      end_line ->
        start_line = Keyword.get(meta, :line, 0)
        {:ok, end_line - start_line - 1}
    end
  end

  defp module_name({:defmodule, _meta, [module_name | _]}) do
    case module_name do
      {:__aliases__, _meta, parts} ->
        parts
        |> Enum.map(&Atom.to_string/1)
        |> Enum.join(".")

      name when is_atom(name) ->
        Atom.to_string(name)

      _ ->
        "module"
    end
  end

  defp module_name(_), do: "module"

  defp priority(actual, max) do
    severity = actual - max

    if severity > 50 do
      :higher
    else
      :normal
    end
  end
end
