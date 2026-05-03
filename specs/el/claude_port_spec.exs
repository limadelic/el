defmodule El.ClaudePort.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.ClaudePort)
    Code.ensure_loaded!(ClaudeCode.CLI.Parser)
    Code.ensure_loaded!(Jason)
    :ok
  end

  describe "init/1" do
    test "returns state with empty buffer" do
      {:ok, state, {:continue, :connect}} = El.ClaudePort.init(cwd: "/tmp")
      assert state.buffer == ""
    end
  end

  describe "handle_info {:data, ...}" do
    test "appends partial data to buffer when no pending request" do
      state = %{port: :fake_port, buffer: "", current_request_id: nil}
      {:noreply, new_state} = El.ClaudePort.handle_info({:fake_port, {:data, "partial"}}, state)
      assert new_state.buffer == "partial"
    end

    test "replies to caller and clears request when result line completes" do
      ref = make_ref()
      from = {self(), ref}
      state = %{
        port: :fake_port,
        buffer: "",
        current_request_id: from,
        session_id: "s1"
      }
      ndjson = ~s({"type":"result","result":"answer"}\n)
      El.ClaudePort.handle_info({:fake_port, {:data, ndjson}}, state)
      assert_receive {^ref, {"answer", _, _}}
    end
  end

  describe "terminate/2" do
    test "returns :ok when port is nil" do
      assert :ok = El.ClaudePort.terminate(:normal, %{port: nil})
    end
  end
end
