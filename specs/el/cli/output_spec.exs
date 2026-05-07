defmodule El.CLI.Output.Spec do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "handle_result/2" do
    test "prints blank line before and after response" do
      output = capture_io(fn ->
        El.CLI.Output.handle_result("hello world", "session")
      end)

      assert String.starts_with?(output, "\n")
      assert output =~ "hello world"
      assert String.ends_with?(output, "\n\n")
    end
  end

  describe "handle_log_result/2" do
    test "prints blank line between entries, no leading blank, no trailing blank" do
      log = [
        {"ask", "first question", "first answer", %{}},
        {"ask", "second question", "second answer", %{}}
      ]

      output = capture_io(fn ->
        El.CLI.Output.handle_log_result(log, "session")
      end)

      lines = String.split(output, "\n")
      assert not String.starts_with?(output, "\n")
      assert Enum.member?(lines, "")
      assert not String.ends_with?(output, "\n\n")
    end

    test "prints single entry with no surrounding blanks" do
      log = [
        {"ask", "question", "answer", %{}}
      ]

      output = capture_io(fn ->
        El.CLI.Output.handle_log_result(log, "session")
      end)

      assert output == "> question\n> answer\n"
    end

    test "prints multiple entries with blank lines between them" do
      log = [
        {"ask", "q1", "a1", %{}},
        {"ask", "q2", "a2", %{}},
        {"ask", "q3", "a3", %{}}
      ]

      output = capture_io(fn ->
        El.CLI.Output.handle_log_result(log, "session")
      end)

      assert output =~ "> q1\n> a1\n\n> q2\n> a2\n\n> q3\n> a3\n"
    end

    test "handles entries with empty response" do
      log = [
        {"ask", "prompt 1", "", %{}},
        {"ask", "prompt 2", "response", %{}}
      ]

      output = capture_io(fn ->
        El.CLI.Output.handle_log_result(log, "session")
      end)

      assert output =~ "> prompt 1\n\n> prompt 2\n> response\n"
    end
  end
end
