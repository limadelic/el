defmodule El.Session.Spec do
  use ExUnit.Case

  setup do
    state = %{
      name: :test_session,
      claude_pid: nil,
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
      store_module: MockSessionStore,
      opts: [],
      claude_opts: []
    }

    {:ok, state: state}
  end

  describe "detect_routes/1" do
    test "returns empty list for text without routes" do
      assert El.Session.Api.detect_routes("hello") == []
    end

    test "returns empty list for bare @name without >" do
      result = El.Session.Api.detect_routes("talk to @donnie about it")
      assert result == []
    end

    test "detects single route" do
      text = "@donnie> you are out of your element"
      result = El.Session.Api.detect_routes(text)

      assert result == [
               {:donnie, "you are out of your element"}
             ]
    end

    test "detects multiple routes on different lines" do
      assert El.Session.Api.detect_routes("@donnie> hey\n@walter> sup") == [
               {:donnie, "hey"},
               {:walter, "sup"}
             ]
    end

    test "detects route with empty payload" do
      assert El.Session.Api.detect_routes("@donnie>") == [{:donnie, ""}]
    end

    test "ignores routes not at start of line" do
      assert El.Session.Api.detect_routes("some text @donnie> payload") == []
    end
  end

  describe "init/1" do
    test "stores session name in state" do
      opts = [claude_module: MockSessionModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:my_session, opts})

      assert state.name == :my_session
    end

    test "initializes messages as empty list" do
      opts = [claude_module: MockSessionModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      assert state.messages == []
    end

    test "stores claude_opts for continue phase" do
      opts = [model: "test-model", claude_module: ModelCaptureModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      assert Keyword.get(state.claude_opts, :model) == "test-model"
    end

    test "stores agent in claude_opts" do
      opts = [agent: "kent", claude_module: ModelCaptureModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      assert Keyword.get(state.claude_opts, :agent) == "kent"
    end

    test "generates and stores session_id" do
      opts = [claude_module: MockSessionModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      assert is_binary(state.session_id)
    end

    test "stores nil claude_pid before continue" do
      opts = [claude_module: MockSessionModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      assert state.claude_pid == nil
    end

    test "stores default task_module" do
      opts = [claude_module: MockSessionModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      assert state.task_module == Task
    end

    test "stores provided task_module" do
      opts = [
        claude_module: MockSessionModule,
        task_module: MockSessionModule
      ]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      assert state.task_module == MockSessionModule
    end
  end

  describe "handle_continue/2 :start_claude" do
    test "calls claude_module.start_link with claude_opts" do
      opts = [
        claude_module: MockSessionModule,
        store_module: MockSessionStore
      ]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      {:noreply, result_state} =
        El.Session.handle_continue(:start_claude, state)

      assert result_state.claude_pid == :mock_pid
    end

    test "loads messages from El.Application" do
      opts = [claude_module: MockSessionModule]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      updated_state = %{state | store_module: MockLoadingStore}

      {:noreply, result_state} =
        El.Session.handle_continue(:start_claude, updated_state)

      expected = [{"tell", "old_message", "old_response", %{}}]
      assert expected == result_state.messages
    end

    test "sets claude_pid to nil on start failure" do
      opts = [
        claude_module: FailingModule,
        store_module: MockSessionStore
      ]

      {:ok, state, {:continue, :start_claude}} =
        El.Session.init({:test_session, opts})

      {:noreply, result_state} =
        El.Session.handle_continue(:start_claude, state)

      assert result_state.claude_pid == nil
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
      {:noreply, returned_state} =
        El.Session.handle_cast({:tell, "hello"}, %{
          state
          | task_module: MockTaskModule,
            alive_fn: fn _ -> false end
        })

      assert [{"tell", "hello", "", %{ref: ref}}] = returned_state.messages
      assert is_reference(ref)
    end

    test "does not store message for routed tells", %{
      state: state,
      alive_fn_target: alive_fn
    } do
      cast_msg = {:tell, "@target> message"}
      updated_state = %{state | alive_fn: alive_fn}

      {:noreply, returned_state} =
        El.Session.handle_cast(cast_msg, updated_state)

      assert returned_state.messages == []
    end
  end

  describe "handle_cast/2 :store_tell" do
    test "replaces pending entry with response", %{state: state} do
      ref = make_ref()
      pending_state = %{state | messages: [{"tell", "msg", "", %{ref: ref}}]}

      {:noreply, returned_state} =
        El.Session.handle_cast(
          {:store_tell, ref, "msg", "response"},
          pending_state
        )

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

      cast_msg = {:store_tell, ref1, "msg", "done first"}

      {:noreply, returned_state} =
        El.Session.handle_cast(cast_msg, pending_state)

      assert [
               {"tell", "msg", "done first", %{}},
               {"tell", "msg", "", %{ref: ^ref2}}
             ] = returned_state.messages
    end

    test "appends when no pending entry exists", %{state: state} do
      ref = make_ref()

      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, ref, "msg", "response"}, state)

      assert [{"tell", "msg", "response", %{}}] = returned_state.messages
    end

    test "deletes pending entry from DETS on completion", %{state: state} do
      ref = make_ref()
      pending_state = %{state | messages: [{"tell", "msg", "", %{ref: ref}}]}

      {:noreply, returned_state} =
        El.Session.handle_cast(
          {:store_tell, ref, "msg", "response"},
          pending_state
        )

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
        El.Session.handle_cast(
          {:cast_store_relay, "message", "response"},
          state
        )

      assert length(returned_state.messages) == 1
    end

    test "stores message type as relay", %{message_tuple: {type, _, _, _}} do
      assert type == "relay"
    end

    test "stores from metadata with session name",
         %{message_tuple: {_, _, _, metadata}} do
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
        El.Session.handle_cast(
          {:tell_ask, :target, "message"},
          %{state | alive_fn: alive_fn}
        )

      assert length(returned_state.messages) == 1
    end
  end

  describe "handle_call/2 :ask" do
    test "returns noreply and spawns task", %{state: state} do
      from = {self(), make_ref()}
      updated_state = %{state | task_module: MockTaskModule}

      assert {:noreply, _state} =
               El.Session.handle_call({:ask, "test"}, from, updated_state)
    end

    test "filters out self-routes", %{state: state} do
      from = {self(), make_ref()}

      {:noreply, _state} =
        El.Session.handle_call({:ask, "@test_session> test"}, from, %{
          state
          | task_module: MockTaskModule
        })
    end

    test "stores pending entry immediately", %{state: state} do
      from = {self(), make_ref()}
      updated_state = %{state | task_module: MockTaskModule}

      {:noreply, returned_state} =
        El.Session.handle_call({:ask, "test question"}, from, updated_state)

      assert [{"ask", "test question", "", %{ref: ref}}] =
               returned_state.messages

      assert is_reference(ref)
    end

    test "does not store pending entry when ask has routes", %{
      state: state
    } do
      from = {self(), make_ref()}

      alive_fn = fn
        :target -> true
        _ -> false
      end

      updated_state = %{
        state
        | task_module: MockTaskModule,
          alive_fn: alive_fn
      }

      {:noreply, returned_state} =
        El.Session.handle_call(
          {:ask, "@target> routed question"},
          from,
          updated_state
        )

      assert returned_state.messages == []
    end
  end

  describe "handle_cast/2 :complete_ask" do
    test "appends when no pending entry exists", %{state: state} do
      from = {self(), make_ref()}
      ref = make_ref()
      cast_msg = {:complete_ask, from, "test", "response", ref}

      {:noreply, returned_state} =
        El.Session.handle_cast(cast_msg, state)

      assert [{"ask", "test", "response", %{}}] = returned_state.messages
    end

    test "replies to caller with response", %{state: state} do
      caller_ref = make_ref()
      from = {self(), caller_ref}
      cast_ref = make_ref()

      El.Session.handle_cast(
        {:complete_ask, from, "test", "the answer", cast_ref},
        state
      )

      assert_receive {^caller_ref, "the answer"}
    end

    test "stores exact message content", %{state: state} do
      from = {self(), make_ref()}
      ref = make_ref()

      {:noreply, returned_state} =
        El.Session.handle_cast(
          {:complete_ask, from, "my question", "42", ref},
          state
        )

      [{_, message, response, _}] = returned_state.messages
      assert message == "my question"
      assert response == "42"
    end

    test "replaces pending entry with response", %{state: state} do
      from = {self(), make_ref()}
      ref = make_ref()
      pending_state = %{state | messages: [{"ask", "hello", "", %{ref: ref}}]}

      {:noreply, returned_state} =
        El.Session.handle_cast(
          {:complete_ask, from, "hello", "response", ref},
          pending_state
        )

      assert [{"ask", "hello", "response", %{}}] = returned_state.messages
    end

    test "replaces correct entry when duplicates exist",
         %{state: state} do
      from = {self(), make_ref()}
      ref1 = make_ref()
      ref2 = make_ref()

      pending_state = %{
        state
        | messages: [
            {"ask", "question", "", %{ref: ref1}},
            {"ask", "question", "", %{ref: ref2}}
          ]
      }

      cast_msg = {:complete_ask, from, "question", "answer first", ref1}

      {:noreply, returned_state} =
        El.Session.handle_cast(cast_msg, pending_state)

      assert [
               {"ask", "question", "answer first", %{}},
               {"ask", "question", "", %{ref: ^ref2}}
             ] = returned_state.messages
    end

    test "deletes pending entry from DETS on completion",
         %{state: state} do
      from = {self(), make_ref()}
      ref = make_ref()
      msg = [{"ask", "question", "", %{ref: ref}}]
      pending_state = %{state | messages: msg}

      cast_msg = {:complete_ask, from, "question", "answer", ref}

      {:noreply, returned_state} =
        El.Session.handle_cast(cast_msg, pending_state)

      assert [{"ask", "question", "answer", %{}}] = returned_state.messages
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
      {:reply, _messages, returned_state} =
        El.Session.handle_call(:log, :from, state)

      assert returned_state == state
    end

    test "returns empty list when no messages", %{state: state} do
      {:reply, messages, _returned_state} =
        El.Session.handle_call(:log, :from, state)

      assert messages == []
    end
  end

  describe "handle_call/2 {:log, count}" do
    test "{:log, :all} returns all messages", %{state: state} do
      messages = [
        {"type1", "msg1", "resp1", %{}},
        {"type2", "msg2", "resp2", %{}}
      ]

      state_with_messages = %{state | messages: messages}

      {:reply, returned_messages, _returned_state} =
        El.Session.handle_call({:log, :all}, :from, state_with_messages)

      assert returned_messages == messages
    end

    test "{:log, 1} returns last 1 message", %{state: state} do
      messages = [
        {"type1", "msg1", "resp1", %{}},
        {"type2", "msg2", "resp2", %{}}
      ]

      state_with_messages = %{state | messages: messages}

      {:reply, returned_messages, _returned_state} =
        El.Session.handle_call({:log, 1}, :from, state_with_messages)

      expected = [{"type2", "msg2", "resp2", %{}}]
      assert returned_messages == expected
    end

    test "{:log, 3} returns last 3 messages", %{state: state} do
      messages = [
        {"type1", "msg1", "resp1", %{}},
        {"type2", "msg2", "resp2", %{}},
        {"type3", "msg3", "resp3", %{}},
        {"type4", "msg4", "resp4", %{}}
      ]

      state_with_messages = %{state | messages: messages}

      {:reply, returned_messages, _returned_state} =
        El.Session.handle_call({:log, 3}, :from, state_with_messages)

      assert returned_messages == [
               {"type2", "msg2", "resp2", %{}},
               {"type3", "msg3", "resp3", %{}},
               {"type4", "msg4", "resp4", %{}}
             ]
    end

    test "{:log, N} where N > length returns all messages", %{
      state: state
    } do
      messages = [
        {"type1", "msg1", "resp1", %{}},
        {"type2", "msg2", "resp2", %{}}
      ]

      state_with_messages = %{state | messages: messages}

      {:reply, returned_messages, _returned_state} =
        El.Session.handle_call({:log, 10}, :from, state_with_messages)

      assert returned_messages == messages
    end

    test "{:log, count} with empty messages returns empty list",
         %{state: state} do
      {:reply, returned_messages, _returned_state} =
        El.Session.handle_call({:log, 3}, :from, state)

      assert returned_messages == []
    end

    test "returns state unchanged", %{state: state} do
      messages = [{"type1", "msg1", "resp1", %{}}]
      state_with_messages = %{state | messages: messages}

      {:reply, _returned_messages, returned_state} =
        El.Session.handle_call({:log, 1}, :from, state_with_messages)

      assert returned_state == state_with_messages
    end
  end

  describe "handle_call/2 :ask_tell" do
    setup %{state: state} do
      alive_fn_target = fn
        :target -> true
        _ -> false
      end

      alive_fn_down = fn _target -> false end

      {:ok,
       state: state,
       alive_fn_target: alive_fn_target,
       alive_fn_down: alive_fn_down}
    end

    test "returns route message when target running",
         %{state: state, alive_fn_target: alive_fn} do
      Mox.stub(El.MockSessionApi, :tell, fn _, _ -> :ok end)

      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert response == "-> target"
    end

    test "stores message when target running",
         %{state: state, alive_fn_target: alive_fn} do
      Mox.stub(El.MockSessionApi, :tell, fn _, _ -> :ok end)

      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert length(returned_state.messages) == 1
    end

    test "returns not running message when target down",
         %{state: state, alive_fn_down: alive_fn} do
      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask_tell, :missing, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert response == "missing is not running"
    end

    test "stores relay message",
         %{state: state, alive_fn_target: alive_fn} do
      Mox.stub(El.MockSessionApi, :tell, fn _, _ -> :ok end)

      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert length(returned_state.messages) == 1
    end
  end

  describe "handle_cast/2 with dead claude_pid" do
    test "respawns claude with session_id when pid is nil",
         %{state: state} do
      dead_state = %{
        state
        | claude_pid: nil,
          claude_module: SessionIdCaptureModule,
          task_module: MockTaskModule,
          opts: [model: "test"]
      }

      {:noreply, respawned} =
        El.Session.handle_cast({:tell, "test"}, dead_state)

      assert respawned.claude_pid == "captured-session-id"
    end
  end

  describe "handle_info/2" do
    test "clears claude_pid on EXIT from claude process", %{state: state} do
      updated_state = %{state | claude_pid: :mock_pid}

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :killed}, updated_state)

      assert returned_state.claude_pid == nil
    end

    test "clears pending_calls on EXIT from claude process",
         %{state: state} do
      updated_state = %{state | claude_pid: :mock_pid}

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :killed}, updated_state)

      assert returned_state.pending_calls == []
    end

    test "replies to pending calls on EXIT", %{state: state} do
      ref = make_ref()
      from = {self(), ref}

      state_with_pending = %{
        state
        | pending_calls: [from],
          claude_pid: :mock_pid
      }

      El.Session.handle_info({:EXIT, :mock_pid, :crash}, state_with_pending)

      assert_receive {^ref, "(error)"}
    end

    test "preserves state on EXIT from different pid", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :other_pid, :normal}, state)

      assert returned_state == state
    end

    test "preserves state on unknown message", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_info(:unknown_message, state)

      assert returned_state == state
    end

    test "adds crash entry to state.messages on abnormal EXIT", %{
      state: state
    } do
      updated_state = %{state | claude_pid: :mock_pid}

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :killed}, updated_state)

      assert [{"crash", "session died", ":killed", %{}}] =
               returned_state.messages
    end

    test "does not store crash entry on normal EXIT reason", %{
      state: state
    } do
      updated_state = %{state | claude_pid: :mock_pid}

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :normal}, updated_state)

      assert returned_state.messages == []
    end
  end

  describe "terminate/2" do
    test "stores crash entry on abnormal exit", %{state: state} do
      updated_state = %{state | store_module: MockVerifyingStore}
      El.Session.terminate(:kill, updated_state)

      expected_msg = {
        :store_message,
        :test_session,
        {"crash", "Session crashed", ":kill", %{}}
      }

      assert_received ^expected_msg
    end

    test "does not store entry on normal exit", %{state: state} do
      El.Session.terminate(:normal, state)
    end

    test "does not store entry on shutdown exit", %{state: state} do
      El.Session.terminate(:shutdown, state)
    end

    test "does not store entry on shutdown with reason", %{state: state} do
      El.Session.terminate({:shutdown, :reason}, state)
    end
  end

  describe "handle_call/2 :agent" do
    test "returns nil when no agent in opts", %{state: state} do
      {:reply, agent, _returned_state} =
        El.Session.handle_call(:agent, :from, state)

      assert agent == nil
    end

    test "returns agent when set in opts", %{state: state} do
      state_with_agent = %{state | opts: [agent: "kent"]}

      {:reply, agent, _returned_state} =
        El.Session.handle_call(:agent, :from, state_with_agent)

      assert agent == "kent"
    end
  end

  describe "handle_call/2 :clear" do
    test "stops old claude process", %{state: state} do
      {:ok, old_pid} = Agent.start_link(fn -> nil end)

      {:reply, :ok, _} =
        El.Session.handle_call(:clear, :from, %{
          state
          | claude_pid: old_pid,
            claude_module: MockSessionModule
        })

      refute Process.alive?(old_pid)
    end

    test "generates new session_id different from old", %{state: state} do
      {:reply, :ok, returned_state} =
        El.Session.handle_call(:clear, :from, %{
          state
          | claude_module: MockSessionModule
        })

      assert returned_state.session_id != "test-session-id"
      assert is_binary(returned_state.session_id)
    end

    test "starts new claude process via claude_module", %{state: state} do
      {:reply, :ok, returned_state} =
        El.Session.handle_call(:clear, :from, %{
          state
          | claude_module: MockSessionModule
        })

      assert returned_state.claude_pid == :mock_pid
    end

    test "clears state.messages to empty list", %{state: state} do
      state_with_messages = %{
        state
        | messages: [{"tell", "old message", "response", %{}}],
          claude_module: MockSessionModule
      }

      {:reply, :ok, returned_state} =
        El.Session.handle_call(:clear, :from, state_with_messages)

      assert returned_state.messages == []
    end

    test "deletes DETS messages via El.Application.delete_session_messages",
         %{state: state} do
      El.Session.handle_call(:clear, :from, %{
        state
        | claude_module: MockSessionModule,
          store_module: MockVerifyingStore
      })

      assert_received {:delete_session_messages, :test_session}
    end

    test "returns :ok reply", %{state: state} do
      {:reply, reply, _returned_state} =
        El.Session.handle_call(:clear, :from, %{
          state
          | claude_module: MockSessionModule
        })

      assert reply == :ok
    end
  end

  describe "Api.info/1" do
    test "returns default info when session does not exist" do
      result = El.Session.Api.info(:nonexistent_session)

      assert result == %{messages: 0, last_prompt: nil, last_response: nil}
    end
  end

  describe "handle_call/2 :info" do
    test "returns message count when messages exist", %{state: state} do
      state_with_messages = %{state | messages: [{"ask", "q1", "a1", %{}}, {"tell", "q2", "a2", %{}}]}

      {:reply, reply, _returned_state} =
        El.Session.handle_call(:info, :from, state_with_messages)

      assert reply.messages == 2
    end

    test "returns zero message count when no messages", %{state: state} do
      {:reply, reply, _returned_state} =
        El.Session.handle_call(:info, :from, state)

      assert reply.messages == 0
    end

    test "returns nil last_prompt when messages empty", %{state: state} do
      {:reply, reply, _returned_state} =
        El.Session.handle_call(:info, :from, state)

      assert reply.last_prompt == nil
    end

    test "returns nil last_response when messages empty", %{state: state} do
      {:reply, reply, _returned_state} =
        El.Session.handle_call(:info, :from, state)

      assert reply.last_response == nil
    end

    test "returns last message prompt", %{state: state} do
      state_with_messages = %{state | messages: [{"ask", "first", "a1", %{}}, {"tell", "second", "a2", %{}}]}

      {:reply, reply, _returned_state} =
        El.Session.handle_call(:info, :from, state_with_messages)

      assert reply.last_prompt == "second"
    end

    test "returns last message response", %{state: state} do
      state_with_messages = %{state | messages: [{"ask", "first", "a1", %{}}, {"tell", "second", "response2", %{}}]}

      {:reply, reply, _returned_state} =
        El.Session.handle_call(:info, :from, state_with_messages)

      assert reply.last_response == "response2"
    end

    test "returns state unchanged", %{state: state} do
      {:reply, _reply, returned_state} =
        El.Session.handle_call(:info, :from, state)

      assert returned_state == state
    end
  end
end

defmodule MockSessionStore do
  def store_message(_, _), do: :ok
  def load_messages(_), do: []
  def delete_message(_, _), do: :ok
  def delete_session_messages(_), do: :ok
end

defmodule MockLoadingStore do
  def load_messages(:test_session) do
    [{"tell", "old_message", "old_response", %{}}]
  end

  def store_message(_, _), do: :ok
  def delete_message(_, _), do: :ok
  def delete_session_messages(_), do: :ok
end

defmodule MockVerifyingStore do
  def store_message(name, entry) do
    send(self(), {:store_message, name, entry})
    :ok
  end

  def load_messages(_), do: []
  def delete_message(_, _), do: :ok

  def delete_session_messages(name) do
    send(self(), {:delete_session_messages, name})
    :ok
  end
end
