defmodule El.Session.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(El.MessageStore)

    on_exit(fn ->
      Application.delete_env(:el, :message_store)
    end)

    Application.put_env(:el, :message_store, El.MessageStore)
    Mimic.stub(El.MessageStore, :lookup, fn _ -> [] end)
    Mimic.stub(El.MessageStore, :insert, fn _, _ -> :ok end)

    state = %{
      name: :test_session,
      claude_pid: :mock_pid,
      session_id: "test-session-id",
      messages: [],
      pending_calls: [],
      claude_module: MockSessionModule,
      task_module: MockSessionModule,
      alive_fn: fn
        :target -> true
        _ -> false
      end,
      registry_module: MockSessionModule,
      opts: []
    }

    {:ok, state: state}
  end

  describe "detect_routes/1" do
    test "returns empty list for text without routes" do
      assert El.Session.detect_routes("hello") == []
    end

    test "returns empty list for bare @name without >" do
      assert El.Session.detect_routes("talk to @donnie about it") == []
    end

    test "detects single route" do
      assert El.Session.detect_routes("@donnie> you are out of your element") == [
               {:donnie, "you are out of your element"}
             ]
    end

    test "detects multiple routes on different lines" do
      assert El.Session.detect_routes("@donnie> hey\n@walter> sup") == [
               {:donnie, "hey"},
               {:walter, "sup"}
             ]
    end

    test "detects route with empty payload" do
      assert El.Session.detect_routes("@donnie>") == [{:donnie, ""}]
    end

    test "ignores routes not at start of line" do
      assert El.Session.detect_routes("some text @donnie> payload") == []
    end
  end

  describe "init/1" do
    test "stores session name in state" do
      {:ok, state} = El.Session.init({:my_session, [claude_module: MockSessionModule]})

      assert state.name == :my_session
    end

    test "initializes messages as empty list" do
      {:ok, state} = El.Session.init({:test_session, [claude_module: MockSessionModule]})

      assert state.messages == []
    end

    test "passes model to claude start_link" do
      {:ok, state} =
        El.Session.init({:test_session, [model: "test-model", claude_module: ModelCaptureModule]})

      assert state.claude_pid == :mock_pid
    end

    test "generates and stores session_id" do
      {:ok, state} = El.Session.init({:test_session, [claude_module: MockSessionModule]})

      assert is_binary(state.session_id)
    end

    test "stores claude_pid from successful start" do
      {:ok, state} = El.Session.init({:test_session, [claude_module: MockSessionModule]})

      assert state.claude_pid == :mock_pid
    end

    test "stops on claude start failure" do
      assert {:stop, _reason} = El.Session.init({:test_session, [claude_module: FailingModule]})
    end

    test "stores default task_module" do
      {:ok, state} = El.Session.init({:test_session, [claude_module: MockSessionModule]})

      assert state.task_module == Task
    end

    test "stores provided task_module" do
      {:ok, state} =
        El.Session.init(
          {:test_session, [claude_module: MockSessionModule, task_module: MockSessionModule]}
        )

      assert state.task_module == MockSessionModule
    end

  end

  describe "handle_cast/2 :tell" do
    setup %{state: state} do
      alive_fn_target = fn
        :target -> true
        _ -> false
      end

      {:ok, state: state, alive_fn_target: alive_fn_target}
    end

    test "stores message immediately and spawns task", %{state: state} do
      Mimic.expect(Task, :start, fn _fun -> {:ok, :task_pid} end)

      {:noreply, returned_state} =
        El.Session.handle_cast({:tell, "hello"}, %{
          state
          | task_module: Task,
            alive_fn: fn _ -> false end
        })

      assert [{"tell", "hello", "", %{ref: ref}}] = returned_state.messages
      assert is_reference(ref)
    end

    test "does not store message for routed tells", %{
      state: state,
      alive_fn_target: alive_fn
    } do
      {:noreply, returned_state} =
        El.Session.handle_cast({:tell, "@target> message"}, %{state | alive_fn: alive_fn})

      assert returned_state.messages == []
    end
  end

  describe "handle_cast/2 :store_tell" do
    test "replaces pending entry with response", %{state: state} do
      ref = make_ref()
      pending_state = %{state | messages: [{"tell", "msg", "", %{ref: ref}}]}

      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, ref, "msg", "response"}, pending_state)

      assert [{"tell", "msg", "response", %{}}] = returned_state.messages
    end

    test "replaces correct entry when duplicates exist", %{state: state} do
      ref1 = make_ref()
      ref2 = make_ref()

      pending_state = %{
        state
        | messages: [
            {"tell", "msg", "", %{ref: ref1}},
            {"tell", "msg", "", %{ref: ref2}}
          ]
      }

      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, ref1, "msg", "done first"}, pending_state)

      assert [{"tell", "msg", "done first", %{}}, {"tell", "msg", "", %{ref: ^ref2}}] =
               returned_state.messages
    end

    test "appends when no pending entry exists", %{state: state} do
      ref = make_ref()

      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, ref, "msg", "response"}, state)

      assert [{"tell", "msg", "response", %{}}] = returned_state.messages
    end
  end

  describe "handle_cast/2 :cast_store_relay" do
    setup %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:cast_store_relay, "msg", "resp"}, state)

      [message_tuple] = returned_state.messages
      {:ok, message_tuple: message_tuple}
    end

    test "appends relay message to log", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:cast_store_relay, "message", "response"}, state)

      assert length(returned_state.messages) == 1
    end

    test "stores message type as relay", %{message_tuple: {type, _, _, _}} do
      assert type == "relay"
    end

    test "stores from metadata with session name", %{message_tuple: {_, _, _, metadata}} do
      assert metadata == %{from: :test_session}
    end
  end

  describe "handle_cast/2 :tell_ask" do
    test "stores relay message", %{state: state} do
      alive_fn = fn
        :target -> false
        _ -> false
      end

      {:noreply, returned_state} =
        El.Session.handle_cast({:tell_ask, :target, "message"}, %{state | alive_fn: alive_fn})

      assert length(returned_state.messages) == 1
    end
  end

  describe "handle_call/2 :ask" do
    test "returns noreply and spawns task", %{state: state} do
      Mimic.expect(Task, :start, fn _fun -> {:ok, :task_pid} end)
      from = {self(), make_ref()}

      assert {:noreply, _state} =
               El.Session.handle_call({:ask, "test"}, from, %{state | task_module: Task})
    end

    test "filters out self-routes", %{state: state} do
      Mimic.stub(Task, :start, fn _fun -> {:ok, :task_pid} end)
      from = {self(), make_ref()}

      {:noreply, _state} =
        El.Session.handle_call({:ask, "@test_session> test"}, from, %{state | task_module: Task})
    end
  end

  describe "handle_cast/2 :complete_ask" do
    test "stores message in log", %{state: state} do
      from = {self(), make_ref()}

      {:noreply, returned_state} =
        El.Session.handle_cast({:complete_ask, from, "test", "response"}, state)

      assert [{"ask", "test", "response", %{}}] = returned_state.messages
    end

    test "replies to caller with response", %{state: state} do
      ref = make_ref()
      from = {self(), ref}

      El.Session.handle_cast({:complete_ask, from, "test", "the answer"}, state)

      assert_receive {^ref, "the answer"}
    end

    test "stores exact message content", %{state: state} do
      from = {self(), make_ref()}

      {:noreply, returned_state} =
        El.Session.handle_cast({:complete_ask, from, "my question", "42"}, state)

      [{_, message, response, _}] = returned_state.messages
      assert message == "my question"
      assert response == "42"
    end
  end

  describe "handle_call/2 :log" do
    test "returns messages from state", %{state: state} do
      state_with_messages = %{state | messages: [{"type", "msg", "resp", %{}}]}

      {:reply, messages, _returned_state} =
        El.Session.handle_call(:log, :from, state_with_messages)

      assert messages == [{"type", "msg", "resp", %{}}]
    end

    test "returns state unchanged", %{state: state} do
      {:reply, _messages, returned_state} = El.Session.handle_call(:log, :from, state)

      assert returned_state == state
    end

    test "returns empty list when no messages", %{state: state} do
      {:reply, messages, _returned_state} = El.Session.handle_call(:log, :from, state)

      assert messages == []
    end
  end

  describe "handle_call/2 :ask_tell" do
    setup %{state: state} do
      alive_fn_target = fn
        :target -> true
        _ -> false
      end

      alive_fn_down = fn _target -> false end

      {:ok, state: state, alive_fn_target: alive_fn_target, alive_fn_down: alive_fn_down}
    end

    test "returns route message when target running", %{state: state, alive_fn_target: alive_fn} do
      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert response == "-> target"
    end

    test "stores message when target running", %{state: state, alive_fn_target: alive_fn} do
      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert length(returned_state.messages) == 1
    end

    test "returns not running message when target down", %{state: state, alive_fn_down: alive_fn} do
      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask_tell, :missing, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert response == "missing is not running"
    end

    test "stores relay message", %{state: state, alive_fn_target: alive_fn} do
      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert length(returned_state.messages) == 1
    end
  end

  describe "handle_cast/2 with dead claude_pid" do
    test "respawns claude with session_id when pid is nil", %{state: state} do
      Mimic.expect(Task, :start, fn _fun -> {:ok, :task_pid} end)
      dead_state = %{
        state
        | claude_pid: nil,
          claude_module: SessionIdCaptureModule,
          task_module: Task,
          opts: [model: "test"]
      }

      {:noreply, respawned} = El.Session.handle_cast({:tell, "test"}, dead_state)

      assert respawned.claude_pid == "captured-session-id"
    end
  end

  describe "handle_info/2" do
    test "clears claude_pid on EXIT from claude process", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :killed}, state)

      assert returned_state.claude_pid == nil
      assert returned_state.pending_calls == []
    end

    test "replies to pending calls on EXIT", %{state: state} do
      ref = make_ref()
      from = {self(), ref}
      state_with_pending = %{state | pending_calls: [from]}

      El.Session.handle_info({:EXIT, :mock_pid, :crash}, state_with_pending)

      assert_receive {^ref, "(error)"}
    end

    test "preserves state on EXIT from different pid", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :other_pid, :normal}, state)

      assert returned_state == state
    end

    test "preserves state on unknown message", %{state: state} do
      {:noreply, returned_state} = El.Session.handle_info(:unknown_message, state)

      assert returned_state == state
    end

    test "adds crash entry to state.messages on abnormal EXIT", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :killed}, state)

      assert [{"crash", "session died", ":killed", %{}}] = returned_state.messages
    end

    test "does not store crash entry on normal EXIT reason", %{state: state} do
      Mimic.reject(El.MessageStore, :insert, 2)

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :normal}, state)

      assert returned_state.messages == []
    end

    test "clears claude_pid on normal EXIT reason", %{state: state} do
      Mimic.reject(El.MessageStore, :insert, 2)

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :normal}, state)

      assert returned_state.claude_pid == nil
    end
  end


  describe "terminate/2" do
    test "stores crash entry on abnormal exit", %{state: state} do
      Mimic.expect(El.MessageStore, :insert, fn :test_session, entry ->
        assert {"crash", "Session crashed", ":kill", %{}} = entry
        :ok
      end)

      El.Session.terminate(:kill, state)
    end

    test "does not store entry on normal exit", %{state: state} do
      Mimic.reject(El.MessageStore, :insert, 2)

      El.Session.terminate(:normal, state)
    end

    test "does not store entry on shutdown exit", %{state: state} do
      Mimic.reject(El.MessageStore, :insert, 2)

      El.Session.terminate(:shutdown, state)
    end

    test "does not store entry on shutdown with reason", %{state: state} do
      Mimic.reject(El.MessageStore, :insert, 2)

      El.Session.terminate({:shutdown, :reason}, state)
    end
  end
end
