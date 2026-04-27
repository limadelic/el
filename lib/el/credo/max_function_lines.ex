defmodule El.Credo.MaxFunctionLines do
  use Credo.Check, category: :refactor, base_priority: :normal

  alias Credo.SourceFile
  alias Credo.Code

  def param_defaults do
    [max_lines: 5]
  end

  def explanations do
    [
      check: "Functions should be small and focused.",
      params: [
        max_lines: "The maximum number of lines a function body can have."
      ]
    ]
  end

  def run(%SourceFile{} = source_file, params) do
    max_lines = params |> Keyword.get(:max_lines, 5)

    Code.prewalk(source_file, &check_function(&1, &2, max_lines))
  end

  defp check_function({:def, meta, [_head | _tail]} = ast, issues, max_lines) do
    {ast, check_lines(ast, max_lines, meta, issues)}
  end

  defp check_function({:defp, meta, [_head | _tail]} = ast, issues, max_lines) do
    {ast, check_lines(ast, max_lines, meta, issues)}
  end

  defp check_function({:defmacro, meta, [_head | _tail]} = ast, issues, max_lines) do
    {ast, check_lines(ast, max_lines, meta, issues)}
  end

  defp check_function(ast, issues, _max_lines) do
    {ast, issues}
  end

  defp check_lines(ast, max_lines, meta, issues) do
    case find_function_body_lines(meta) do
      {:ok, body_lines} ->
        if body_lines > max_lines do
          issue = %Credo.Issue{
            check: El.Credo.MaxFunctionLines,
            message: "Function body is too long (#{body_lines} lines, max is #{max_lines}).",
            filename: nil,
            line_no: meta[:line],
            column: meta[:column],
            trigger: function_name(ast),
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

  defp find_function_body_lines(meta) do
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

  defp function_name({_type, _meta, [{:when, _when_meta, [name | _]} | _]}) do
    function_name({nil, nil, [name]})
  end

  defp function_name({_type, _meta, [{fname, _fname_meta, _args} | _]}) do
    Atom.to_string(fname)
  end

  defp function_name({_type, _meta, [name | _]}) do
    case name do
      {fname, _meta, _args} -> Atom.to_string(fname)
      fname when is_atom(fname) -> Atom.to_string(fname)
      _ -> "function"
    end
  end

  defp function_name(_), do: "function"

  defp priority(actual, max) do
    severity = actual - max

    if severity > 10 do
      :higher
    else
      :normal
    end
  end
end
