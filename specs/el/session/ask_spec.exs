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
    test "spawn_ask tells the completer to complete with reporter, ask_info, and routes" do
      ask_info = {self(), "test message", make_ref()}
      server_pid = self()
      routes = []

      expect(El.MockCompleter, :complete, fn _target, ^server_pid, ^ask_info, ^routes ->
        :ok
      end)

      state = %{
        claude_pid: :unused,
        messages: [],
        pending_calls: [],
        completer: El.MockCompleter
      }

      El.Session.Ask.spawn_ask(state, ask_info, routes, server_pid)

      verify!()
    end
  end

  describe "finalize_ask/6" do
    setup do
      Application.put_env(:el, :store_module, El.MockStoreModule)
      on_exit(fn -> Application.delete_env(:el, :store_module) end)
      stub(El.MockStoreModule, :delete_message, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :store_message, fn _, _ -> :ok end)
      :ok
    end

    @tag timeout: 1000
    test "calls store with model in metadata when model is provided" do
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

    @tag timeout: 1000
    test "calls store with nil when model is nil" do
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

    @tag timeout: 1000
    test "replies to caller with response" do
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

    @tag timeout: 1000
    test "deletes pending entry from DETS on completion" do
      pending_ref = make_ref()
      state = %{
        name: :test_session,
        messages: [{"ask", "question", "", %{ref: pending_ref}}],
        pending_calls: [self()],
        store_module: El.MockStoreModule
      }

      from = {self(), make_ref()}

      returned_state = El.Session.Ask.finalize_ask(state, from, pending_ref, "question", "answer", "claude-3")

      assert returned_state.messages == [{"ask", "question", "answer", %{model: "claude-3"}}]
    end
  end

  describe "prepare_ask/3" do
    setup do
      Application.put_env(:el, :store_module, El.MockStoreModule)
      on_exit(fn -> Application.delete_env(:el, :store_module) end)
      stub(El.MockStoreModule, :delete_message, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :store_message, fn _, _ -> :ok end)
      :ok
    end

    test "stores pending entry with empty response on prepare_ask" do
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
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [],
        store_module: El.MockStoreModule
      }

      from = {self(), make_ref()}

      {_ref, new_state} = El.Session.Ask.prepare_ask(state, from, "test question")

      ref = new_state.messages |> hd() |> elem(3) |> Map.fetch!(:ref)
      assert is_reference(ref)
    end

    test "does not store pending entry when ask has routes" do
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

  describe "reset_session/1" do
    setup do
      Application.put_env(:el, :store_module, El.MockStoreModule)
      on_exit(fn -> Application.delete_env(:el, :store_module) end)

      stub(El.MockStoreModule, :delete_message, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :store_message, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :delete_session_messages, fn _ -> :ok end)

      state = %{
        name: :test_session,
        messages: [{"tell", "old message", "response", %{}}],
        opts: [],
        session_id: "test-session-id",
        claude_pid: :old_pid,
        claude_opts: [],
        claude_module: MockSessionModule,
        store_module: El.MockStoreModule
      }

      {:ok, state: state}
    end

    test "reset_session generates a session_id different from previous", %{state: state} do
      new_state = El.Session.Ask.reset_session(state)
      assert new_state.session_id != "test-session-id"
    end

    test "reset_session generates a binary session_id", %{state: state} do
      new_state = El.Session.Ask.reset_session(state)
      assert is_binary(new_state.session_id)
    end

    test "clears state.messages to empty list", %{state: state} do
      new_state = El.Session.Ask.reset_session(state)
      assert new_state.messages == []
    end

    test "deletes DETS messages via store_module.delete_session_messages", %{state: state} do
      test_pid = self()
      expect(El.MockStoreModule, :delete_session_messages, fn name ->
        send(test_pid, {:delete_session_messages, name})
        :ok
      end)

      El.Session.Ask.reset_session(state)

      assert_receive {:delete_session_messages, :test_session}
    end

    test "sets claude_pid via claude_module", %{state: state} do
      new_state = El.Session.Ask.reset_session(state)

      assert new_state.claude_pid == :mock_pid
    end
  end
end
