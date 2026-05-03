defmodule El.Session.Ask.Spec do
  use ExUnit.Case
  import Mox

  setup do
    Application.put_env(:claude_code, :session_module, MockClaudeCodeSession)
    {:ok, pid} = TestClaudePortStub.start_link(nil)

    on_exit(fn ->
      Application.delete_env(:claude_code, :session_module)
    end)

    {:ok, test_pid: pid}
  end

  setup :verify_on_exit!

  describe "ask_work/3" do
    @tag timeout: 1000
    test "returns result from ask_work", %{test_pid: test_pid} do
      {result, _, _} = El.Session.Claude.ask_work(test_pid, "test", [])
      assert result == "test result"
    end

    @tag timeout: 1000
    test "returns model from ask_work", %{test_pid: test_pid} do
      {_, model, _} = El.Session.Claude.ask_work(test_pid, "test", [])
      assert model == "test-model"
    end

    @tag timeout: 1000
    test "returns session_id from ask_work", %{test_pid: test_pid} do
      {_, _, session_id} = El.Session.Claude.ask_work(test_pid, "test", [])
      assert session_id == "test-session-id"
    end
  end

  describe "model plumbing end-to-end" do
    @tag timeout: 1000
    test "model and session_id flow from ask_work through spawn_ask_task to complete_ask cast", %{test_pid: test_pid} do
      state = %{
        claude_pid: test_pid,
        messages: [],
        pending_calls: [],
        task_module: Task
      }

      ask_info = {self(), "test message", make_ref()}
      server_pid = self()

      El.Session.Ask.spawn_ask(state, ask_info, [], server_pid)

      assert_receive {:"$gen_cast",
                      {:complete_ask, _, "test message", "test result", _,
                       "test-model", "test-session-id"}},
                     1000
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
        pending_calls: [self()],
        store_module: El.MockStoreModule
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
        pending_calls: [self()],
        store_module: El.MockStoreModule
      }

      from = {self(), make_ref()}
      ref = make_ref()

      El.Session.Ask.finalize_ask(state, from, ref, "question", "answer", nil)
    end

    test "replies to caller with response" do
      stub(El.MockStoreModule, :delete_ask_entry, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :store_ask_entry, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :replace_ask, fn messages, _, _, _, _ -> messages end)

      Application.put_env(:el, :store_module, El.MockStoreModule)

      on_exit(fn ->
        Application.delete_env(:el, :store_module)
      end)

      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()],
        store_module: El.MockStoreModule
      }

      caller_ref = make_ref()
      from = {self(), caller_ref}

      El.Session.Ask.finalize_ask(state, from, make_ref(), "test", "the answer", "claude-3")

      assert_receive {^caller_ref, "the answer"}
    end

    test "deletes pending entry from DETS on completion" do
      stub(El.MockStoreModule, :delete_ask_entry, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :store_ask_entry, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :replace_ask, fn _messages, _ref, _message, _response, _model ->
        [{"ask", "question", "answer", %{}}]
      end)

      Application.put_env(:el, :store_module, El.MockStoreModule)

      on_exit(fn ->
        Application.delete_env(:el, :store_module)
      end)

      state = %{
        name: :test_session,
        messages: [{"ask", "question", "", %{ref: make_ref()}}],
        pending_calls: [self()],
        store_module: El.MockStoreModule
      }

      from = {self(), make_ref()}
      ref = make_ref()

      returned_state = El.Session.Ask.finalize_ask(state, from, ref, "question", "answer", "claude-3")

      assert returned_state.messages == [{"ask", "question", "answer", %{}}]
    end
  end

  describe "prepare_ask/3" do
    test "stores pending entry with empty response on prepare_ask" do
      stub(El.MockStoreModule, :store_message, fn _, _ -> :ok end)

      Application.put_env(:el, :store_module, El.MockStoreModule)

      on_exit(fn ->
        Application.delete_env(:el, :store_module)
      end)

      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [],
        store_module: El.MockStoreModule
      }

      from = {self(), make_ref()}

      {_ref, new_state} = El.Session.Ask.prepare_ask(state, from, "test question")

      assert [{"ask", "test question", "", %{ref: _}}] = new_state.messages
    end

    test "stores pending entry with a reference on prepare_ask" do
      stub(El.MockStoreModule, :store_message, fn _, _ -> :ok end)

      Application.put_env(:el, :store_module, El.MockStoreModule)

      on_exit(fn ->
        Application.delete_env(:el, :store_module)
      end)

      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [],
        store_module: El.MockStoreModule
      }

      from = {self(), make_ref()}

      {_ref, new_state} = El.Session.Ask.prepare_ask(state, from, "test question")

      [{_, _, _, %{ref: ref}}] = new_state.messages
      assert is_reference(ref)
    end

    test "does not store pending entry when ask has routes" do
      stub(El.MockStoreModule, :store_message, fn _, _ -> :ok end)

      Application.put_env(:el, :store_module, El.MockStoreModule)

      on_exit(fn ->
        Application.delete_env(:el, :store_module)
      end)

      alive_fn = fn
        :target -> true
        _ -> false
      end

      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [],
        store_module: El.MockStoreModule,
        alive_fn: alive_fn
      }

      from = {self(), make_ref()}

      {_ref, new_state} = El.Session.Ask.prepare_ask(state, from, "@target> routed question")

      assert new_state.messages == []
    end
  end
end
