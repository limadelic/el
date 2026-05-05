defmodule El.CLI.Start.CardBox do
  def box_frame([]), do: [top_border(), bottom_border()]
  def box_frame(rows) do
    first_two = Enum.take(rows, 2)
    rest = Enum.drop(rows, 2)
    [top_border()] ++ first_two ++ Enum.map(rest, &frame_row/1) ++ [bottom_border()]
  end

  def top_border, do: "╭" <> String.duplicate("─", 48) <> "╮"
  def bottom_border, do: "╰" <> String.duplicate("─", 48) <> "╯"

  def frame_row(content) do
    padded = String.pad_trailing(content, 46)
    "│ " <> padded <> " │"
  end

  def frame_pair_row(left, right) do
    right_block = truncate_right_block(right)
    content = compose_pair_content(left, right_block)
    "│ " <> String.pad_trailing(content, 46) <> " │"
  end

  def compose_pair_content(left, right_block) do
    left <> filler_between(left, right_block) <> right_block
  end

  def filler_between(left, right) do
    String.duplicate(" ", filler_length(left, right))
  end

  def filler_length(left, right) do
    max(0, 46 - String.length(left) - String.length(right))
  end

  def truncate_right_block(right) do
    do_truncate_right(String.split(right, ": ", parts: 2), right)
  end

  def do_truncate_right([label, value], _right), do: label <> ": " <> truncate_value(value)
  def do_truncate_right(_parts, right), do: right

  def truncate_value(value) do
    truncate_with_ellipsis(value, 9)
  end

  def truncate_with_ellipsis(text, max_len) do
    text_len = String.length(text)
    do_truncate(text_len, text, max_len)
  end

  def do_truncate(len, text, max_len) when len <= max_len, do: text
  def do_truncate(_len, text, max_len) do
    ellipsis = "…"
    available = max_len - String.length(ellipsis)
    ellipsis <> String.slice(text, -available..-1)
  end
end
