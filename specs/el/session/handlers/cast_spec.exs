defmodule El.Session.Handlers.Cast.Spec do
  use ExUnit.Case
  import Mox

  alias El.Session.Handlers.Cast

  setup :verify_on_exit!

  describe "handle with complete_ask and session_id" do
    test "session_meta.insert called with state.name, agent, session_id, model" do
      pid = self()

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

      Cast.handle({:complete_ask, pid, "msg", "resp", make_ref(), "model", "sid"}, state)

      assert_receive {:call, "session_name", "test_agent", "sid", "model"}
    end
  end
end
