defmodule El.CLI.Start.CardBox.Spec do
  use ExUnit.Case, async: true

  describe "El.CLI.Start.CardBox.box_frame/1" do
    test "returns top and bottom border for empty rows" do
      result = El.CLI.Start.CardBox.box_frame([])
      assert length(result) == 2
    end

    test "includes top border" do
      rows = ["model: opus"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      assert String.starts_with?(Enum.at(result, 0), "╭")
    end

    test "includes bottom border" do
      rows = ["model: opus"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      assert String.ends_with?(Enum.at(result, -1), "╯")
    end

    test "preserves first row as-is" do
      rows = ["model: opus"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      first_data_row = Enum.at(result, 1)
      assert first_data_row == "model: opus"
    end

    test "preserves first row as-is in two row input" do
      rows = ["model: opus", "msgs:  5"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      first_data_row = Enum.at(result, 1)
      assert first_data_row == "model: opus"
    end

    test "preserves second row as-is in two row input" do
      rows = ["model: opus", "msgs:  5"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      second_data_row = Enum.at(result, 2)
      assert second_data_row == "msgs:  5"
    end

    test "frames third row with left border" do
      rows = ["row1", "row2", "row3", "row4"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      third_data_row = Enum.at(result, 3)
      assert String.starts_with?(third_data_row, "│ ")
    end

    test "frames third row with right border" do
      rows = ["row1", "row2", "row3", "row4"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      third_data_row = Enum.at(result, 3)
      assert String.ends_with?(third_data_row, " │")
    end

    test "frames fourth row with left border" do
      rows = ["row1", "row2", "row3", "row4"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      fourth_data_row = Enum.at(result, 4)
      assert String.starts_with?(fourth_data_row, "│ ")
    end

    test "frames fourth row with right border" do
      rows = ["row1", "row2", "row3", "row4"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      fourth_data_row = Enum.at(result, 4)
      assert String.ends_with?(fourth_data_row, " │")
    end

    test "all framed rows have 50 char width" do
      rows = ["row1", "row2", "row3", "row4"]
      result = El.CLI.Start.CardBox.box_frame(rows)
      framed_rows = Enum.slice(result, 3..4)
      assert Enum.all?(framed_rows, fn line -> String.length(line) == 50 end)
    end
  end
end
