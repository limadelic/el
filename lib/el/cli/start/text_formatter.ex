defmodule El.CLI.Start.TextFormatter do
  @behaviour El.Behaviours.TextFormatter

  def format_response(nil), do: []
  def format_response(response) do
    response
    |> wrap_text(46)
    |> cap_lines(2)
  end

  defp wrap_text(text, width) do
    text
    |> String.split(" ")
    |> build_lines(width, "", [])
  end

  defp build_lines([], _width, "", acc), do: Enum.reverse(acc)
  defp build_lines([], _width, current, acc), do: Enum.reverse([String.trim(current) | acc])

  defp build_lines([word | rest], width, "", acc) do
    build_lines(rest, width, word, acc)
  end

  defp build_lines([word | rest], width, current, acc) do
    wrap = %{rest: rest, width: width, current: current, acc: acc}
    add_word(word, wrap, String.trim(current <> " " <> word))
  end

  defp add_word(word, wrap, new_line) do
    do_add_word(String.length(new_line), word, wrap, new_line)
  end

  defp do_add_word(len, _word, %{rest: rest, width: width, acc: acc}, new_line) when len <= width do
    build_lines(rest, width, new_line, acc)
  end

  defp do_add_word(_len, word, %{rest: rest, width: width, current: current, acc: acc}, _new_line) do
    build_lines(rest, width, word, [String.trim(current) | acc])
  end

  defp cap_lines(lines, max), do: Enum.take(lines, max)
end
