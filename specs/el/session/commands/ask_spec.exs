defmodule El.Session.Commands.Ask.Spec do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "model plumbing end-to-end" do
    test "model and session_id flow from ask_work through spawn_ask_task to complete_ask cast" do
      state = %{
        claude_pid: :test_pid,
        claude_session: El.MockSessionClaude,
        messages: [],
        pending_calls: [],
        task_module: Task
      }

      ask_info = {self(), "test message", make_ref()}
      server_pid = self()

      expect(El.MockSessionClaude, :ask_work, fn _, _, _ -> {"test result", "test-model", "test-session-id"} end)

      El.Session.Commands.Ask.spawn_ask(state, ask_info, [], server_pid)

      assert_receive {:"$gen_cast",
                      {:complete_ask, _, "test message", "test result", _,
                       "test-model", "test-session-id"}}
    end
  end

  describe "finalize_ask/2" do
    setup do
      Application.put_env(:el, :store_module, El.MockStoreModule)
      on_exit(fn -> Application.delete_env(:el, :store_module) end)
      stub(El.MockStoreModule, :delete_message, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :store_message, fn _, _, _ -> :ok end)
      :ok
    end

    test "calls store with model in metadata when model is provided" do
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()],
        store_module: El.MockStoreModule,
        opts: []
      }

      from = {self(), make_ref()}
      ref = make_ref()

      El.Session.Commands.Ask.finalize_ask(state, %{from: from, ref: ref, message: "question", response: "answer", model: "claude-3"})
    end

    test "calls store with nil when model is nil" do
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()],
        store_module: El.MockStoreModule,
        opts: []
      }

      from = {self(), make_ref()}
      ref = make_ref()

      El.Session.Commands.Ask.finalize_ask(state, %{from: from, ref: ref, message: "question", response: "answer", model: nil})
    end

    test "replies to caller with response" do
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [self()],
        store_module: El.MockStoreModule,
        opts: []
      }

      caller_ref = make_ref()
      from = {self(), caller_ref}

      El.Session.Commands.Ask.finalize_ask(state, %{from: from, ref: make_ref(), message: "test", response: "the answer", model: "claude-3"})

      assert_receive {^caller_ref, "the answer"}
    end

    test "deletes pending entry from DETS on completion" do
      pending_ref = make_ref()
      state = %{
        name: :test_session,
        messages: [{"ask", "question", "", %{ref: pending_ref}}],
        pending_calls: [self()],
        store_module: El.MockStoreModule,
        opts: []
      }

      from = {self(), make_ref()}

      returned_state = El.Session.Commands.Ask.finalize_ask(state, %{from: from, ref: pending_ref, message: "question", response: "answer", model: "claude-3"})

      assert returned_state.messages == [{"ask", "question", "answer", %{model: "claude-3"}}]
    end
  end

  describe "prepare_ask/3" do
    setup do
      Application.put_env(:el, :store_module, El.MockStoreModule)
      on_exit(fn -> Application.delete_env(:el, :store_module) end)
      stub(El.MockStoreModule, :delete_message, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :store_message, fn _, _, _ -> :ok end)
      :ok
    end

    test "stores pending entry with empty response on prepare_ask" do
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [],
        store_module: El.MockStoreModule,
        opts: []
      }

      from = {self(), make_ref()}

      {_ref, new_state} = El.Session.Commands.Ask.prepare_ask(state, from, "test question")

      assert [{"ask", "test question", "", %{ref: _}}] = new_state.messages
    end

    test "stores pending entry with a reference on prepare_ask" do
      state = %{
        name: :test_session,
        messages: [],
        pending_calls: [],
        store_module: El.MockStoreModule,
        opts: []
      }

      from = {self(), make_ref()}

      {_ref, new_state} = El.Session.Commands.Ask.prepare_ask(state, from, "test question")

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

      {_ref, new_state} = El.Session.Commands.Ask.prepare_ask(state, from, "@target> routed question")

      assert new_state.messages == []
    end
  end

  describe "reset_session/1" do
    setup do
      Application.put_env(:el, :store_module, El.MockStoreModule)
      on_exit(fn -> Application.delete_env(:el, :store_module) end)

      stub(El.MockStoreModule, :delete_message, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :store_message, fn _, _ -> :ok end)
      stub(El.MockStoreModule, :delete_session_messages, fn _, _ -> :ok end)

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

    test "reset_session leaves session_id as nil", %{state: state} do
      new_state = El.Session.Commands.Ask.reset_session(state)
      assert new_state.session_id == nil
    end

    test "reset_session strips :session_id from claude_opts", %{state: state} do
      state_with_session_id = %{state | opts: [session_id: "some-id", other: "value"]}
      new_state = El.Session.Commands.Ask.reset_session(state_with_session_id)
      assert Keyword.get(new_state.claude_opts, :session_id) == nil
      assert Keyword.get(new_state.claude_opts, :other) == "value"
    end

    test "clears state.messages to empty list", %{state: state} do
      new_state = El.Session.Commands.Ask.reset_session(state)
      assert new_state.messages == []
    end

    test "deletes DETS messages via store_module.delete_session_messages", %{state: state} do
      test_pid = self()
      expect(El.MockStoreModule, :delete_session_messages, fn name, _opts ->
        send(test_pid, {:delete_session_messages, name})
        :ok
      end)

      El.Session.Commands.Ask.reset_session(state)

      assert_receive {:delete_session_messages, :test_session}
    end

    test "sets claude_pid via claude_module", %{state: state} do
      new_state = El.Session.Commands.Ask.reset_session(state)

      assert new_state.claude_pid == :mock_pid
    end
  end

  describe "session_id lifecycle after reset" do
    setup do
      Application.put_env(:el, :store_module, El.MockStoreModule)
      on_exit(fn -> Application.delete_env(:el, :store_module) end)

      stub(El.MockStoreModule, :delete_message, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :store_message, fn _, _, _ -> :ok end)
      stub(El.MockStoreModule, :delete_session_messages, fn _, _ -> :ok end)

      state = %{
        name: :test_session,
        messages: [],
        opts: [],
        session_id: "old-uuid-aaa",
        claude_pid: :test_pid,
        claude_opts: [],
        claude_session: El.MockSessionClaude,
        claude_module: MockSessionModule,
        store_module: El.MockStoreModule,
        pending_calls: []
      }

      {:ok, state: state}
    end

    test "session_id becomes nil after reset_session", %{state: state} do
      reset_state = El.Session.Commands.Ask.reset_session(state)
      assert reset_state.session_id == nil
    end

    @tag timeout: 5000
    test "session_id repopulates from ask_work response", %{state: state} do
      reset_state = El.Session.Commands.Ask.reset_session(state)
      assert reset_state.session_id == nil

      expect(El.MockSessionClaude, :ask_work, fn _, _, _ ->
        {"test result", "test-model", "new-uuid-from-claude"}
      end)

      {response, model, session_id} = reset_state.claude_session.ask_work(
        reset_state.claude_pid,
        "test message",
        []
      )

      assert response == "test result"
      assert model == "test-model"
      assert session_id == "new-uuid-from-claude"

      caller_ref = make_ref()
      ask = %{
        from: {self(), caller_ref},
        ref: make_ref(),
        message: "test message",
        response: response,
        model: model
      }

      finalized = El.Session.Commands.Ask.finalize_ask(reset_state, ask)
      updated_state = %{finalized | session_id: session_id}

      assert updated_state.session_id == "new-uuid-from-claude"
      assert_receive {^caller_ref, "test result"}, 1000
    end
  end
end
