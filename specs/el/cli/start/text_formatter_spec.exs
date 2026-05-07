defmodule El.CLI.Start.TextFormatter.Spec do
  use ExUnit.Case

  describe "format_response/1" do
    setup do
      long_text = "This is a very long response that should wrap to multiple lines because it exceeds the maximum width of 46 characters"
      result = El.CLI.Start.TextFormatter.format_response(long_text)
      {:ok, long_text: long_text, result: result}
    end

    test "returns empty list for nil input" do
      assert El.CLI.Start.TextFormatter.format_response(nil) == []
    end

    test "caps wrapped text at 1 line", %{result: result} do
      assert length(result) == 1
    end

    test "wraps text to 46 char width", %{result: result} do
      assert Enum.all?(result, fn line -> String.length(line) <= 46 end)
    end

    test "caps lines at 1 even with many lines of input" do
      three_lines = "Line1 " <> String.duplicate("word ", 20) <> "Line2 " <> String.duplicate("word ", 20) <> "Line3"
      result = El.CLI.Start.TextFormatter.format_response(three_lines)

      assert length(result) == 1
    end

    test "handles short text that needs no wrapping" do
      short_text = "Short response"
      result = El.CLI.Start.TextFormatter.format_response(short_text)

      assert length(result) >= 1
    end
  end

  describe "format_prompt/1" do
    test "returns empty list for nil input" do
      assert El.CLI.Start.TextFormatter.format_prompt(nil) == []
    end

    test "prefixes short prompt with > " do
      prompt = "Hello, how are you?"
      result = El.CLI.Start.TextFormatter.format_prompt(prompt)

      assert length(result) == 1
      assert String.starts_with?(hd(result), "> ")
    end

    test "handles multi-line prompt" do
      prompt = "Line one\nLine two"
      result = El.CLI.Start.TextFormatter.format_prompt(prompt)

      assert length(result) == 1
      assert String.starts_with?(hd(result), "> ")
    end

    test "caps long single-line prompt to first line only" do
      long_prompt = String.duplicate("word ", 25)
      result = El.CLI.Start.TextFormatter.format_prompt(long_prompt)

      assert length(result) == 1
      assert String.starts_with?(hd(result), "> ")
      assert String.length(hd(result)) <= 46
    end
  end
end
