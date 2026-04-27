defmodule El.Credo.LineCheck do
  @default_threshold 50

  def find_body_lines(meta) do
    case extract_end_line(meta) do
      nil -> :error
      end_line -> {:ok, end_line - Keyword.get(meta, :line, 0) - 1}
    end
  end

  defp extract_end_line(meta) do
    case Keyword.fetch(meta, :end_line) do
      {:ok, line} -> line
      :error -> extract_from_expression(meta)
    end
  end

  defp extract_from_expression(meta) do
    case Keyword.fetch(meta, :end_of_expression) do
      {:ok, expr_meta} -> Keyword.get(expr_meta, :line)
      :error -> nil
    end
  end

  def issue_for(check_module, name, body_lines, max_lines, meta) do
    new_issue(
      check_module,
      format_message(name, body_lines, max_lines),
      meta,
      name,
      calc_priority(body_lines - max_lines, @default_threshold)
    )
  end

  defp new_issue(check, message, meta, trigger, priority) do
    %Credo.Issue{
      check: check,
      message: message,
      filename: nil,
      line_no: meta[:line],
      column: meta[:column],
      trigger: trigger,
      priority: priority,
      category: :refactor,
      exit_status: 2
    }
  end

  defp format_message(name, body_lines, max_lines) do
    "#{name} is too long (#{body_lines} lines, max is #{max_lines})."
  end

  defp calc_priority(severity, threshold) do
    if severity > threshold, do: :higher, else: :normal
  end
end
