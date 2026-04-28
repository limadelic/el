defmodule El.Credo.LineCheck do
  @default_threshold 50
  @base_issue %Credo.Issue{category: :refactor, exit_status: 2}

  def find_body_lines(meta) do
    meta |> extract_end_line() |> to_result(meta)
  end

  defp to_result(nil, _meta), do: :error
  defp to_result(end_line, meta), do: {:ok, count_lines(end_line, meta)}

  defp count_lines(end_line, meta) do
    end_line - Keyword.get(meta, :line, 0) - 1
  end

  defp extract_end_line(meta) do
    meta |> Keyword.get(:end_line) |> extract_end_line_impl(meta)
  end

  defp extract_end_line_impl(nil, meta), do: extract_from_expression(meta)
  defp extract_end_line_impl(end_line, _meta), do: end_line

  defp extract_from_expression(meta) do
    expr = Keyword.get(meta, :end_of_expression, [])
    Keyword.get(expr, :line)
  end

  def issue_for(check, name, lines, max, meta_and_file) do
    {meta, filename} = meta_and_file
    msg = format_message(name, lines, max)
    build_issue(check, msg, meta, calc_priority(lines - max), filename)
  end

  defp format_message(name, lines, max) do
    "#{name} is too long (#{lines} lines, max is #{max})."
  end

  defp build_issue(check, msg, meta, pri, filename) do
    %{
      @base_issue
      | check: check,
        message: msg,
        line_no: get_line(meta),
        column: get_column(meta),
        priority: pri,
        filename: filename
    }
  end

  defp get_line(meta), do: meta[:line]
  defp get_column(meta), do: meta[:column]

  defp calc_priority(severity)
       when severity > @default_threshold, do: :higher

  defp calc_priority(_severity), do: :normal
end
