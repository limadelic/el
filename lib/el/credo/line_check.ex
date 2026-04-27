defmodule El.Credo.LineCheck do
  @default_threshold 50
  @base_issue %Credo.Issue{category: :refactor, exit_status: 2}

  def find_body_lines(meta) do
    meta |> extract_end_line() |> to_result(meta)
  end

  defp to_result(nil, _meta), do: :error

  defp to_result(end_line, meta) do
    {:ok, end_line - Keyword.get(meta, :line, 0) - 1}
  end

  defp extract_end_line(meta) do
    Keyword.get(meta, :end_line) ||
      extract_from_expression(meta)
  end

  defp extract_from_expression(meta) do
    expr = Keyword.get(meta, :end_of_expression, [])
    Keyword.get(expr, :line)
  end

  def issue_for(check, name, lines, max, meta) do
    msg = "#{name} is too long (#{lines} lines, max is #{max})."
    build_issue(check, msg, meta, calc_priority(lines - max))
  end

  defp build_issue(check, msg, meta, pri) do
    %{
      @base_issue
      | check: check,
        message: msg,
        line_no: meta[:line],
        column: meta[:column],
        priority: pri
    }
  end

  defp calc_priority(severity)
       when severity > @default_threshold, do: :higher

  defp calc_priority(_severity), do: :normal
end
