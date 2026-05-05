defmodule El.CLI.Start.CardBox.Spec do
  use ExUnit.Case, async: true

  describe "El.CLI.Start.CardBox.box_frame/1" do
    setup do
      {:ok,
       empty_rows: [],
       single_row: [El.CLI.Start.CardBox.frame_pair_row("name", "test")],
       multi_rows: [
         El.CLI.Start.CardBox.frame_pair_row("name", "test"),
         El.CLI.Start.CardBox.frame_pair_row("id", "123"),
         "model: opus",
         "msgs:  5"
       ]}
    end

    test "returns top and bottom border for empty rows", %{empty_rows: empty} do
      result = El.CLI.Start.CardBox.box_frame(empty)
      assert length(result) == 2
    end

    test "frames all rows to 50 chars total", %{single_row: rows} do
      result = El.CLI.Start.CardBox.box_frame(rows)
      assert Enum.all?(result, fn line -> String.length(line) == 50 end)
    end

    test "preserves first two rows as-is in output", %{multi_rows: rows} do
      result = El.CLI.Start.CardBox.box_frame(rows)
      first_data_row = Enum.at(result, 1)
      second_data_row = Enum.at(result, 2)
      assert String.starts_with?(first_data_row, "│ ")
      assert String.starts_with?(second_data_row, "│ ")
    end

    test "applies frame_row to rows after first two", %{multi_rows: rows} do
      result = El.CLI.Start.CardBox.box_frame(rows)
      third_data_row = Enum.at(result, 3)
      fourth_data_row = Enum.at(result, 4)
      assert String.ends_with?(third_data_row, " │")
      assert String.ends_with?(fourth_data_row, " │")
    end
  end

  describe "El.CLI.Start.CardBox.frame_row/1" do
    setup do
      {:ok, content: "model: opus"}
    end

    test "pads content to 46 chars between borders", %{content: content} do
      result = El.CLI.Start.CardBox.frame_row(content)
      assert String.length(result) == 50
    end

    test "frames with box borders", %{content: content} do
      result = El.CLI.Start.CardBox.frame_row(content)
      assert String.starts_with?(result, "│ ")
      assert String.ends_with?(result, " │")
    end
  end

  describe "El.CLI.Start.CardBox.frame_pair_row/2" do
    setup do
      {:ok,
       short_left: "name: test",
       short_right: "id: 123",
       long_right: "cwd: /very/long/path/that/exceeds/limits"}
    end

    test "combines left and right with filler", %{short_left: left, short_right: right} do
      result = El.CLI.Start.CardBox.frame_pair_row(left, right)
      assert String.contains?(result, left)
      assert String.contains?(result, right)
    end

    test "total padded content is 46 chars", %{short_left: left, short_right: right} do
      result = El.CLI.Start.CardBox.frame_pair_row(left, right)
      assert String.length(result) == 50
    end

    test "truncates right block with ellipsis when too long", %{short_left: left, long_right: right} do
      result = El.CLI.Start.CardBox.frame_pair_row(left, right)
      assert String.contains?(result, "…")
    end
  end

  describe "El.CLI.Start.CardBox.compose_pair_content/2" do
    setup do
      {:ok, left: "name: test", right: "id: 123"}
    end

    test "returns left + filler + right", %{left: left, right: right} do
      result = El.CLI.Start.CardBox.compose_pair_content(left, right)
      assert String.starts_with?(result, left)
      assert String.ends_with?(result, right)
    end

    test "filler fills gap between left and right", %{left: left, right: right} do
      result = El.CLI.Start.CardBox.compose_pair_content(left, right)
      total_len = String.length(left) + String.length(right)
      filler_len = String.length(result) - total_len
      assert filler_len >= 0
    end
  end

  describe "El.CLI.Start.CardBox.filler_between/2" do
    setup do
      {:ok,
       short_left: "a",
       short_right: "b",
       long_left: String.duplicate("x", 30),
       long_right: String.duplicate("y", 20)}
    end

    test "returns spaces when left and right fit", %{short_left: left, short_right: right} do
      result = El.CLI.Start.CardBox.filler_between(left, right)
      assert String.length(result) > 0
      assert result == String.duplicate(" ", String.length(result))
    end

    test "returns no spaces when content fills 46 chars", %{long_left: left, long_right: right} do
      result = El.CLI.Start.CardBox.filler_between(left, right)
      assert String.length(result) == 0
    end
  end

  describe "El.CLI.Start.CardBox.filler_length/2" do
    setup do
      {:ok,
       short_pair: {"a", "b"},
       medium_pair: {"name: test", "id: 123"},
       overfull_pair: {String.duplicate("x", 30), String.duplicate("y", 20)}}
    end

    test "calculates positive filler for short content", %{short_pair: {left, right}} do
      result = El.CLI.Start.CardBox.filler_length(left, right)
      assert result > 0
    end

    test "calculates filler for medium content", %{medium_pair: {left, right}} do
      result = El.CLI.Start.CardBox.filler_length(left, right)
      assert result > 0
      assert String.length(left) + result + String.length(right) == 46
    end

    test "returns zero when content exceeds 46 chars", %{overfull_pair: {left, right}} do
      result = El.CLI.Start.CardBox.filler_length(left, right)
      assert result == 0
    end
  end

  describe "El.CLI.Start.CardBox.truncate_right_block/1" do
    setup do
      {:ok,
       short_value: "id: 123",
       long_value: "cwd: /very/long/path/that/exceeds/the/limit",
       no_colon: "nodelabel"}
    end

    test "returns unchanged value without colon separator", %{no_colon: value} do
      result = El.CLI.Start.CardBox.truncate_right_block(value)
      assert result == value
    end

    test "truncates value part of label: value with ellipsis", %{long_value: value} do
      result = El.CLI.Start.CardBox.truncate_right_block(value)
      assert String.contains?(result, "cwd: ")
      assert String.contains?(result, "…")
    end

    test "preserves short label: value unchanged", %{short_value: value} do
      result = El.CLI.Start.CardBox.truncate_right_block(value)
      assert result == value
    end
  end

  describe "El.CLI.Start.CardBox.truncate_value/1" do
    setup do
      {:ok,
       short_value: "123",
       at_limit: "123456789",
       over_limit: "1234567890"}
    end

    test "returns short value unchanged", %{short_value: value} do
      result = El.CLI.Start.CardBox.truncate_value(value)
      assert result == value
    end

    test "returns value at 9 char limit unchanged", %{at_limit: value} do
      result = El.CLI.Start.CardBox.truncate_value(value)
      assert result == value
    end

    test "adds ellipsis to value over 9 chars", %{over_limit: value} do
      result = El.CLI.Start.CardBox.truncate_value(value)
      assert String.contains?(result, "…")
      assert String.length(result) <= 9
    end
  end

  describe "El.CLI.Start.CardBox.truncate_with_ellipsis/2" do
    setup do
      {:ok,
       text: "abcdefghij",
       max_len: 5}
    end

    test "returns text unchanged if under max length", %{text: text} do
      result = El.CLI.Start.CardBox.truncate_with_ellipsis(text, 20)
      assert result == text
    end

    test "adds ellipsis and truncates when over max", %{text: text, max_len: max_len} do
      result = El.CLI.Start.CardBox.truncate_with_ellipsis(text, max_len)
      assert String.length(result) <= max_len
      assert String.contains?(result, "…")
    end

    test "ellipsis edge case at exact boundary" do
      text = "12345"
      result = El.CLI.Start.CardBox.truncate_with_ellipsis(text, 3)
      assert String.length(result) <= 3
    end
  end

  describe "El.CLI.Start.CardBox.top_border/0" do
    test "returns top border with 48 dashes" do
      result = El.CLI.Start.CardBox.top_border()
      assert String.starts_with?(result, "╭")
      assert String.ends_with?(result, "╮")
      assert String.length(result) == 50
    end
  end

  describe "El.CLI.Start.CardBox.bottom_border/0" do
    test "returns bottom border with 48 dashes" do
      result = El.CLI.Start.CardBox.bottom_border()
      assert String.starts_with?(result, "╰")
      assert String.ends_with?(result, "╯")
      assert String.length(result) == 50
    end
  end
end
