defmodule El.ClaudePort.Spec do
  use ExUnit.Case
  import Mox

  setup do
    Logger.configure(level: :debug)
    :ok
  end

  setup :verify_on_exit!

  setup_all do
    Code.ensure_loaded!(El.ClaudePort)
    Code.ensure_loaded!(ClaudeCode.CLI.Parser)
    Code.ensure_loaded!(Jason)
    El.ClaudePort.Parser.try_extract_result(~s({"type":"result","result":"warmup"}\n), "warmup-sid")
    El.ClaudePort.Parser.try_extract_result(~s({"type":"system","subtype":"init","model":"m","session_id":"s"}\n), "warmup-sid")
    El.ClaudePort.Parser.try_extract_result("not json\n", "warmup-sid")
    :ok
  end

  setup do
    stub(El.MockParser, :try_extract_result, fn _buffer, _session_id -> :incomplete end)
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
      expect(El.MockParser, :try_extract_result, fn _buffer, "s1" ->
        {:ok, {"answer", "model", "s1"}, ""}
      end)
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

    test "does not reply when system-init line arrives" do
      expect(El.MockParser, :try_extract_result, fn _buffer, "s1" ->
        :incomplete
      end)
      ref = make_ref()
      from = {self(), ref}
      state = %{
        port: :fake_port,
        buffer: "",
        current_request_id: from,
        session_id: "s1"
      }
      ndjson = ~s({"type":"system","subtype":"init","model":"claude-3","session_id":"s2"}\n)
      El.ClaudePort.handle_info({:fake_port, {:data, ndjson}}, state)
      refute_receive _, 0
    end

    test "skips malformed JSON line and processes valid result line" do
      expect(El.MockParser, :try_extract_result, fn _buffer, "s1" ->
        {:ok, {"ok", "model", "s1"}, ""}
      end)
      ref = make_ref()
      from = {self(), ref}
      state = %{
        port: :fake_port,
        buffer: "",
        current_request_id: from,
        session_id: "s1"
      }
      payload = ~s(not json\n{"type":"result","result":"ok"}\n)
      El.ClaudePort.handle_info({:fake_port, {:data, payload}}, state)
      assert_receive {^ref, {"ok", _, _}}
    end
  end

  describe "handle_info {port, :eof}" do
    test "logs debug message" do
      state = %{port: :fake_port, buffer: "", current_request_id: nil}
      logs = ExUnit.CaptureLog.capture_log([level: :debug], fn ->
        El.ClaudePort.handle_info({:fake_port, :eof}, state)
      end)
      assert logs =~ "Claude port EOF"
    end

    test "returns noreply tuple" do
      state = %{port: :fake_port, buffer: "", current_request_id: nil}
      result = El.ClaudePort.handle_info({:fake_port, :eof}, state)
      assert elem(result, 0) == :noreply
    end

    test "preserves port in state" do
      state = %{port: :fake_port, buffer: "", current_request_id: nil}
      {:noreply, new_state} = El.ClaudePort.handle_info({:fake_port, :eof}, state)
      assert new_state.port == state.port
    end

    test "preserves buffer in state" do
      state = %{port: :fake_port, buffer: "", current_request_id: nil}
      {:noreply, new_state} = El.ClaudePort.handle_info({:fake_port, :eof}, state)
      assert new_state.buffer == state.buffer
    end
  end

  describe "terminate/2" do
    test "returns :ok when port is nil" do
      assert :ok = El.ClaudePort.terminate(:normal, %{port: nil})
    end
  end
end
