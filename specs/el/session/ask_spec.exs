defmodule El.Session.Ask.Spec do
  use ExUnit.Case
  import Mox

  @moduletag timeout: 1000

  setup do
    Application.put_env(:claude_code, :session_module, MockClaudeCodeSession)

    on_exit(fn ->
      Application.delete_env(:claude_code, :session_module)
    end)

    :ok
  end

  setup :verify_on_exit!

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
    test "calls store with model in metadata when model is provided" do
      stub(El.MockStoreModule, :delete_ask_entry, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :store_ask_entry, fn _, _ -> :ok end)
      expect(El.MockStoreModule, :replace_ask, fn messages, _ref, _message, _response, model ->
        assert model == "claude-3"
        messages
      end)

      Application.put_env(:el, :store_module, El.MockStoreModule)

      on_exit(fn ->
        Application.delete_env(:el, :store_module)
      end)

      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()]
      }

      from = {self(), make_ref()}
      ref = make_ref()

      El.Session.Ask.finalize_ask(state, from, ref, "question", "answer", "claude-3")
    end

    test "calls store with nil when model is nil" do
      stub(El.MockStoreModule, :delete_ask_entry, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :store_ask_entry, fn _, _ -> :ok end)
      expect(El.MockStoreModule, :replace_ask, fn messages, _ref, _message, _response, model ->
        assert model == nil
        messages
      end)

      Application.put_env(:el, :store_module, El.MockStoreModule)

      on_exit(fn ->
        Application.delete_env(:el, :store_module)
      end)

      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()]
      }

      from = {self(), make_ref()}
      ref = make_ref()

      El.Session.Ask.finalize_ask(state, from, ref, "question", "answer", nil)
    end
  end
end
