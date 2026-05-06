defmodule El.ClaudePort.Buffer.Spec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "El.ClaudePort.Buffer.process/2" do
    test "process returns {:noreply, state} when extraction not ready" do
      stub(El.MockParser, :try_extract_result, fn _buffer, _session_id -> :incomplete end)
      state = %{buffer: "", current_request_id: "req-1", session_id: "sess-1"}
      data = "incomplete"

      result = El.ClaudePort.Buffer.process(data, state)

      assert result == {:noreply, %{buffer: "incomplete", current_request_id: "req-1", session_id: "sess-1"}}
    end

    test "process returns {:reply, from, result, state} when extraction completes" do
      stub(El.MockParser, :try_extract_result, fn _buffer, _session_id -> {:ok, "response", ""} end)
      state = %{buffer: "", current_request_id: "req-1", session_id: "sess-1"}
      data = "complete"

      result = El.ClaudePort.Buffer.process(data, state)

      assert result == {:reply, "req-1", "response", %{buffer: "", current_request_id: nil, session_id: "sess-1"}}
    end
  end
end
