defmodule El.CLI.Start.TextFormatter.Spec do
  use ExUnit.Case

  describe "format_response/1" do
    test "returns empty list for nil input" do
      assert El.CLI.Start.TextFormatter.format_response(nil) == []
    end

    test "caps wrapped text at 2 lines" do
      long_text = "This is a very long response that should wrap to multiple lines because it exceeds the maximum width of 46 characters"
      result = El.CLI.Start.TextFormatter.format_response(long_text)

      assert length(result) <= 2
    end

    test "wraps text to 46 char width" do
      long_text = "This is a very long response that should wrap to multiple lines because it exceeds the maximum width of 46 characters"
      result = El.CLI.Start.TextFormatter.format_response(long_text)

      Enum.each(result, fn line -> assert String.length(line) <= 46 end)
    end

    test "caps lines at 2 even with many lines of input" do
      three_lines = "Line1 " <> String.duplicate("word ", 20) <> "Line2 " <> String.duplicate("word ", 20) <> "Line3"
      result = El.CLI.Start.TextFormatter.format_response(three_lines)

      assert length(result) <= 2
    end

    test "handles short text that needs no wrapping" do
      short_text = "Short response"
      result = El.CLI.Start.TextFormatter.format_response(short_text)

      assert length(result) >= 1
    end
  end
end
