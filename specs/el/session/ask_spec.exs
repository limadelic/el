defmodule El.Session.Ask.Spec do
  use ExUnit.Case

  @moduletag timeout: 1000

  setup do
    Application.put_env(:claude_code, :session_module, MockClaudeCodeSession)

    on_exit(fn ->
      Application.delete_env(:claude_code, :session_module)
    end)

    :ok
  end

  describe "ask_work/3" do
    test "returns tuple with result and model from Claude.ask" do
      {result, model} = El.Session.Claude.ask_work(:test_pid, "test", [])

      assert result == "test result"
      assert model == "test-model"
    end
  end

  describe "model plumbing end-to-end" do
    test "model flows from ask_work through spawn_ask_task to complete_ask cast" do
      state = %{
        claude_pid: :test_pid,
        messages: [],
        pending_calls: [],
        task_module: Task
      }

      ask_info = {self(), "test message", make_ref()}
      server_pid = self()

      El.Session.Ask.spawn_ask(state, ask_info, [], server_pid)

      assert_receive {:"$gen_cast",
                      {:complete_ask, _, "test message", "test result", _,
                       "test-model"}},
                     100
    end
  end

  describe "finalize_ask/6" do
    test "stores model in message metadata when model is provided" do
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()],
        store_module: MockStore
      }

      from = {self(), make_ref()}
      ref = make_ref()

      returned_state = El.Session.Ask.finalize_ask(state, from, ref, "question", "answer", "claude-3")

      assert returned_state.messages == [{"ask", "question", "answer", %{model: "claude-3"}}]
    end

    test "stores empty metadata when model is nil" do
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()],
        store_module: MockStore
      }

      from = {self(), make_ref()}
      ref = make_ref()

      returned_state = El.Session.Ask.finalize_ask(state, from, ref, "question", "answer", nil)

      assert returned_state.messages == [{"ask", "question", "answer", %{}}]
    end
  end
end

defmodule MockStore do
  def delete_ask_entry(_state, _message, _ref), do: :ok
  def store_ask_entry(_state, _entry), do: :ok
  def store_message(_session, _entry), do: :ok
  def delete_message(_session, _entry), do: :ok
end
