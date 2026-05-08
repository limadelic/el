defmodule El.Session.Handlers.Cast.Spec do
  use ExUnit.Case
  import Mox

  alias El.Session.Handlers.Cast

  setup :verify_on_exit!

  describe "handle with complete_ask and nil session_id" do
    test "finalizes ask without persisting session meta" do
      pid = self()
      ref = make_ref()

      stub(El.MockSessionAsk, :finalize_ask, fn state, _ask ->
        state
      end)

      state = %{
        name: "session_name",
        session_id: nil,
        opts: [agent: "test_agent"],
        ask_module: El.MockSessionAsk,
        messages: []
      }

      {:noreply, result_state} =
        Cast.handle({:complete_ask, pid, "msg", "resp", ref, "model", nil}, state)

      assert result_state.session_id == nil
    end
  end

  describe "handle with complete_ask and session_id" do
    test "updates session_id" do
      pid = self()
      ref = make_ref()

      stub(El.MockSessionMeta, :insert, fn _name, _agent, _session_id, _model ->
        :ok
      end)

      stub(El.MockSessionAsk, :finalize_ask, fn state, _ask ->
        state
      end)

      state = %{
        name: "session_name",
        session_id: nil,
        opts: [agent: "test_agent"],
        session_meta: El.MockSessionMeta,
        ask_module: El.MockSessionAsk,
        messages: []
      }

      {:noreply, result_state} =
        Cast.handle({:complete_ask, pid, "msg", "resp", ref, "model", "sid"}, state)

      assert result_state.session_id == "sid"
    end

    test "persists session meta" do
      pid = self()
      ref = make_ref()

      expect(El.MockSessionMeta, :insert, fn name, agent, session_id, model ->
        send(pid, {:call, name, agent, session_id, model})
      end)

      stub(El.MockSessionAsk, :finalize_ask, fn state, _ask ->
        state
      end)

      state = %{
        name: "session_name",
        session_id: nil,
        opts: [agent: "test_agent"],
        session_meta: El.MockSessionMeta,
        ask_module: El.MockSessionAsk,
        messages: []
      }

      {:noreply, _result_state} =
        Cast.handle({:complete_ask, pid, "msg", "resp", ref, "model", "sid"}, state)

      assert_receive {:call, "session_name", "test_agent", "sid", "model"}
    end

    test "complete_ask cast handler populates session_id from Claude response" do
      pid = self()
      ref = make_ref()

      stub(El.MockSessionMeta, :insert, fn _name, _agent, _session_id, _model ->
        :ok
      end)

      stub(El.MockSessionAsk, :finalize_ask, fn state, _ask ->
        state
      end)

      state = %{
        name: "session_name",
        session_id: nil,
        opts: [agent: "test_agent"],
        session_meta: El.MockSessionMeta,
        ask_module: El.MockSessionAsk,
        messages: []
      }

      {:noreply, new_state} =
        Cast.handle({:complete_ask, pid, "any message", "any response", ref, "haiku", "new-uuid-from-claude"}, state)

      assert new_state.session_id == "new-uuid-from-claude"
    end

    test "complete_ask cast handler with nil session_id leaves state.session_id unchanged" do
      pid = self()
      ref = make_ref()

      stub(El.MockSessionAsk, :finalize_ask, fn state, _ask ->
        state
      end)

      state = %{
        name: "session_name",
        session_id: "existing-uuid",
        opts: [agent: "test_agent"],
        ask_module: El.MockSessionAsk,
        messages: []
      }

      {:noreply, new_state} =
        Cast.handle({:complete_ask, pid, "msg", "resp", ref, "haiku", nil}, state)

      assert new_state.session_id == "existing-uuid"
    end
  end
end
