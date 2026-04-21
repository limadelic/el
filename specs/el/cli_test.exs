defmodule El.CLITest do
  use ExUnit.Case, async: true

  defp extract_model_flag(args) do
    case args do
      ["--model", model | rest] -> {String.to_atom(model), rest}
      _ -> {nil, args}
    end
  end

  defp start_opts(model) do
    if model, do: [model: model], else: []
  end

  describe "extract_model_flag/1" do
    test "extracts model when present" do
      {model, rest} = extract_model_flag(["--model", "haiku", "tell", "hello"])
      assert model == :haiku
      assert rest == ["tell", "hello"]
    end

    test "returns nil when no model flag" do
      {model, rest} = extract_model_flag(["tell", "hello"])
      assert model == nil
      assert rest == ["tell", "hello"]
    end

    test "returns nil for empty args" do
      {model, rest} = extract_model_flag([])
      assert model == nil
      assert rest == []
    end

    test "handles multiple flags by only extracting first --model" do
      {model, rest} = extract_model_flag(["--model", "opus", "--other", "value"])
      assert model == :opus
      assert rest == ["--other", "value"]
    end
  end

  describe "start_opts/1" do
    test "returns model option when model present" do
      opts = start_opts(:opus)
      assert opts == [model: :opus]
    end

    test "returns empty list when model nil" do
      opts = start_opts(nil)
      assert opts == []
    end

    test "preserves atom form of model" do
      opts = start_opts(:haiku)
      assert opts == [model: :haiku]
    end
  end

  describe "El.start/2 with model" do
    test "starts session with model option" do
      model = :haiku
      opts = start_opts(model)
      session_name = :"test_session_#{System.unique_integer()}"

      El.start(session_name, opts)

      assert El.Session.alive?(session_name)

      El.kill(session_name)
    end

    test "starts session without model option when nil" do
      opts = start_opts(nil)
      session_name = :"test_session_#{System.unique_integer()}"

      El.start(session_name, opts)

      assert El.Session.alive?(session_name)

      El.kill(session_name)
    end
  end
end
