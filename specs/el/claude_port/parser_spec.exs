defmodule El.ClaudePort.Parser.Spec do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  setup do
    Application.put_env(:el, :cc_parser, El.MockCCParser)
    stub(El.MockCCParser, :normalize_keys, fn json -> json end)
    on_exit(fn -> Application.delete_env(:el, :cc_parser) end)
    :ok
  end

  describe "try_extract_result/2" do
    test "preserves sid when present in result" do
      ndjson = ~s({"type":"system","subtype":"init","model":"m","session_id":"s2"}\n{"type":"result","result":"ok"}\n)
      {:ok, {_result, _model, sid}, _} = El.ClaudePort.Parser.try_extract_result(ndjson, "fallback")
      assert sid == "s2"
    end

    test "falls back to session_id arg when sid is nil" do
      ndjson = ~s({"type":"result","result":"answer"}\n)
      {:ok, {_result, _model, sid}, _} = El.ClaudePort.Parser.try_extract_result(ndjson, "fallback")
      assert sid == "fallback"
    end
  end
end
