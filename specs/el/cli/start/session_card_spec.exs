defmodule El.CLI.Start.SessionCard.Spec do
  use ExUnit.Case, async: false
  import Mox
  setup :verify_on_exit!

  describe "El.CLI.Start.SessionCard.build_card_rows/3" do
    setup do
      Application.put_env(:el, :card_box, El.MockCardBox)
      Application.put_env(:el, :text_formatter, El.MockTextFormatter)
      stub_with(El.MockCardBox, El.CLI.Start.CardBox)
      stub_with(El.MockTextFormatter, El.CLI.Start.TextFormatter)
      on_exit(fn ->
        Application.delete_env(:el, :card_box)
        Application.delete_env(:el, :text_formatter)
      end)

      info = %{
        id: "session-123",
        model: "claude-3-5-sonnet",
        cwd: "/home/user/project",
        messages: 5,
        last_prompt: "Hello, how are you?",
        last_response: "I'm doing well, thanks for asking!"
      }
      {:ok, info: info}
    end

    test "includes name in first row", %{info: info} do
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], info)
      assert Enum.any?(result, &String.contains?(&1, "name:  test_session"))
    end

    test "includes id in first row", %{info: info} do
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], info)
      assert Enum.any?(result, &String.contains?(&1, "id:"))
    end

    test "includes agent when provided in opts", %{info: info} do
      opts = [agent: "kent"]
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "agent: kent"))
    end

    test "includes model from opts when provided", %{info: info} do
      opts = [model: "claude-3-5-opus"]
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "model: claude-3-5-opus"))
    end

    test "includes model from info when opts has no model", %{info: info} do
      opts = []
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "model: claude-3-5-sonnet"))
    end

    test "shows preferred model from opts", %{info: info} do
      opts = [model: "claude-3-5-opus"]
      new_info = %{info | model: "claude-3-5-sonnet"}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, new_info)
      assert Enum.any?(result, &String.contains?(&1, "model: claude-3-5-opus"))
    end

    test "does not show non-preferred model from info", %{info: info} do
      opts = [model: "claude-3-5-opus"]
      new_info = %{info | model: "claude-3-5-sonnet"}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, new_info)
      assert Enum.all?(result, &(!String.contains?(&1, "model: claude-3-5-sonnet")))
    end

    test "includes cwd in second row with agent", %{info: info} do
      opts = [agent: "kent"]
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "cwd:"))
    end

    test "includes cwd in second row with opts model", %{info: info} do
      opts = [model: "claude-3-5-opus"]
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "cwd:"))
    end

    test "includes cwd in second row with info model", %{info: info} do
      opts = []
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "cwd:"))
    end

    test "truncates long cwd values in frame", %{info: info} do
      long_cwd = "/very/long/path/that/exceeds/normal/width/for/display"
      new_info = %{info | cwd: long_cwd}
      opts = [agent: "kent"]
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, new_info)
      pair_row = Enum.find(result, &String.contains?(&1, "agent: kent"))
      assert String.length(pair_row) == 50
    end

    test "includes message count when greater than zero", %{info: info} do
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], info)
      assert Enum.any?(result, &String.contains?(&1, "msgs:  5"))
    end

    test "excludes message row when zero", %{info: info} do
      new_info = %{info | messages: 0}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], new_info)
      assert Enum.all?(result, &(!String.contains?(&1, "msgs:")))
    end

    test "includes prompt when present", %{info: info} do
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], info)
      assert Enum.any?(result, &String.contains?(&1, "> Hello, how are you?"))
    end

    test "excludes prompt when nil", %{info: info} do
      new_info = %{info | last_prompt: nil}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], new_info)
      assert Enum.all?(result, &(!String.contains?(&1, ">")))
    end

    test "includes response when present", %{info: info} do
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], info)
      assert Enum.any?(result, &String.contains?(&1, "doing well"))
    end

    test "excludes response when nil", %{info: info} do
      new_info = %{info | last_response: nil}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], new_info)
      response_present = Enum.any?(result, &String.contains?(&1, "doing well"))
      assert !response_present
    end

    test "includes separator between sections when prompt present", %{info: info} do
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], info)
      separators = Enum.filter(result, &String.contains?(&1, "─"))
      assert length(separators) >= 2
    end

    test "no separators when prompt and response both nil", %{info: info} do
      new_info = %{info | last_prompt: nil, last_response: nil}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", [], new_info)
      separators = Enum.filter(result, &String.contains?(&1, "─"))
      assert length(separators) == 0
    end

    test "agent appears in second left value", %{info: info} do
      opts = [agent: "kent"]
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "agent: kent"))
    end

    test "agent second left value is not nil", %{info: info} do
      opts = [agent: "kent"]
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, info)
      pair_row = Enum.find(result, &String.contains?(&1, "agent: kent"))
      assert pair_row != nil
    end

    test "opts model is shown in display", %{info: info} do
      opts = [model: "opus"]
      new_info = %{info | model: "sonnet"}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, new_info)
      assert Enum.any?(result, &String.contains?(&1, "opus"))
    end

    test "info model is not shown when opts model present", %{info: info} do
      opts = [model: "opus"]
      new_info = %{info | model: "sonnet"}
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, new_info)
      displayed_models = result |> Enum.filter(&String.contains?(&1, "model:"))
      assert Enum.all?(displayed_models, &(!String.contains?(&1, "sonnet")))
    end

    test "returns empty model line only when both nil", %{info: info} do
      new_info = %{info | model: nil}
      opts = []
      result = El.CLI.Start.SessionCard.build_card_rows("test_session", opts, new_info)
      model_lines = Enum.filter(result, &String.contains?(&1, "model:"))
      assert length(model_lines) == 0
    end

    test "agent identity persists in card with explicit agent", %{info: info} do
      opts = [agent: "kent"]
      result = El.CLI.Start.SessionCard.build_card_rows("kento", opts, info)
      assert Enum.any?(result, &String.contains?(&1, "agent: kent"))
    end
  end
end
