defmodule El.ClaudePort.Parser.LineExtractor do
  def extract_all_lines(buffer, acc) do
    apply_extracted_line(extract_one_line(buffer), buffer, acc)
  end

  defp apply_extracted_line({nil, _}, buffer, acc), do: {Enum.reverse(acc), buffer}
  defp apply_extracted_line({line, remaining}, _buffer, acc), do: extract_all_lines(remaining, [line | acc])

  defp extract_one_line(buffer) do
    apply_split(String.split(buffer, "\n", parts: 2), buffer)
  end

  defp apply_split([line, rest], _buffer), do: {line, rest}
  defp apply_split([_incomplete], buffer), do: {nil, buffer}
  defp apply_split([], _buffer), do: {nil, ""}
end
