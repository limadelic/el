defmodule El.Session.Handlers.Tell.Spec do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "tell flow with no routes" do
    test "calls claude_session.ask via state when processing tell" do
      test_pid = self()
      expect(El.MockSessionClaude, :ask, fn pid, msg ->
        send(test_pid, {:asked, pid, msg})
        {"resp", nil, nil}
      end)

      state = %{
        claude_pid: :fake_pid,
        claude_session: El.MockSessionClaude,
        task_module: SyncTask,
        name: :test,
        messages: []
      }

      ref = make_ref()
      El.Session.Handlers.Tell.process_tell(state, "hello", ref, [])

      assert_receive {:asked, :fake_pid, "hello"}
    end

    test "casts store_tell with the response when processing tell" do
      expect(El.MockSessionClaude, :ask, fn _pid, _msg -> {"the answer", nil, nil} end)

      state = %{
        claude_pid: :fake_pid,
        claude_session: El.MockSessionClaude,
        task_module: SyncTask,
        name: :test,
        messages: []
      }

      ref = make_ref()
      El.Session.Handlers.Tell.process_tell(state, "hello", ref, [])

      assert_receive {:"$gen_cast", {:store_tell, ^ref, "hello", "the answer"}}
    end
  end
end
