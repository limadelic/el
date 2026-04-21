defmodule MockSessionModule do
  def start_link(_), do: {:ok, :mock_pid}
end

defmodule MockTaskModule do
  def start(_fun), do: {:ok, :task_pid}
end

defmodule El.Session.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(Task)
    :ok
  end

  setup do
    state = %{
      name: :test_session,
      claude_pid: :mock_pid,
      messages: [],
      claude_module: MockSessionModule,
      task_module: MockSessionModule,
      alive_fn: fn
        :target -> true
        _ -> false
      end,
      registry_module: MockSessionModule
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
      {:ok, capture_agent} = Agent.start_link(fn -> nil end)
      Application.put_env(:el, :capture_agent, capture_agent)

      defmodule ModelCaptureModule do
        def start_link(opts) do
          capture_agent = Application.get_env(:el, :capture_agent)
          Agent.update(capture_agent, fn _ -> opts end)
          {:ok, :mock_pid}
        end
      end

      El.Session.init({:test_session, [model: "test-model", claude_module: ModelCaptureModule]})

      captured_opts = Agent.get(capture_agent, & &1)
      assert captured_opts[:model] == "test-model"

      Application.delete_env(:el, :capture_agent)
    end

    test "stores claude_pid from successful start" do
      {:ok, state} = El.Session.init({:test_session, [claude_module: MockSessionModule]})

      assert state.claude_pid == :mock_pid
    end

    test "stores nil for claude_pid on start failure" do
      defmodule FailingModule do
        def start_link(_), do: {:error, :failed}
      end

      {:ok, state} = El.Session.init({:test_session, [claude_module: FailingModule]})

      assert state.claude_pid == nil
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
    test "starts task to ask claude when no routes" do
      Mimic.stub(Task, :start, fn _fun -> {:ok, :task_pid} end)

      {:noreply, returned_state} =
        El.Session.handle_cast({:tell, "hello"}, %{
          name: :test_session,
          claude_pid: :mock_pid,
          messages: [],
          claude_module: MockSessionModule,
          task_module: Task,
          alive_fn: fn _ -> false end,
          registry_module: MockSessionModule
        })

      assert returned_state.task_module == Task
    end

    test "processes routes when message contains @target" do
      alive_fn = fn
        :target -> true
        _ -> false
      end

      {:noreply, _returned_state} =
        El.Session.handle_cast(
          {:tell, "@target> message"},
          %{
            name: :test_session,
            claude_pid: :mock_pid,
            messages: [],
            claude_module: MockSessionModule,
            task_module: MockSessionModule,
            alive_fn: alive_fn,
            registry_module: MockSessionModule
          }
        )

      :ok
    end
  end

  describe "handle_cast/2 :store_tell" do
    test "appends tell message to log", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, "message", "response"}, state)

      assert length(returned_state.messages) == 1
    end

    test "stores message type as tell", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, "msg", "resp"}, state)

      [{type, _, _, _}] = returned_state.messages
      assert type == "tell"
    end

    test "stores exact message content", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, "test message", "resp"}, state)

      [{_, message, _, _}] = returned_state.messages
      assert message == "test message"
    end

    test "stores exact response content", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, "msg", "test response"}, state)

      [{_, _, response, _}] = returned_state.messages
      assert response == "test response"
    end

    test "stores empty metadata" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: []
      }

      {:noreply, returned_state} =
        El.Session.handle_cast({:store_tell, "msg", "resp"}, state)

      [{_, _, _, metadata}] = returned_state.messages
      assert metadata == %{}
    end
  end

  describe "handle_cast/2 :store_relay" do
    test "appends relay message to log", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:store_relay, "message", "response"}, state)

      assert length(returned_state.messages) == 1
    end

    test "stores message type as relay", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:store_relay, "msg", "resp"}, state)

      [{type, _, _, _}] = returned_state.messages
      assert type == "relay"
    end

    test "stores from metadata with session name", %{state: state} do
      {:noreply, returned_state} =
        El.Session.handle_cast({:store_relay, "msg", "resp"}, state)

      [{_, _, _, metadata}] = returned_state.messages
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
    test "returns binary response when no routes", %{state: state} do
      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask, "test"}, :from, state)

      assert is_binary(response)
    end

    test "stores message in log on ask", %{state: state} do
      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask, "test"}, :from, state)

      assert length(returned_state.messages) == 1
    end

    test "filters out self-routes", %{state: state} do
      {:reply, _response, _returned_state} =
        El.Session.handle_call({:ask, "@test_session> test"}, :from, state)

      :ok
    end

    test "returns route message for single valid route", %{state: state} do
      alive_fn = fn
        :other -> true
        _ -> false
      end

      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask, "@other> test"}, :from, %{state | alive_fn: alive_fn})

      assert response == "-> other"
    end

    test "stores routed message in log", %{state: state} do
      alive_fn = fn
        :other -> true
        _ -> false
      end

      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask, "@other> test"}, :from, %{state | alive_fn: alive_fn})

      assert length(returned_state.messages) == 1
    end

    test "stores exact message content in log", %{state: state} do
      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask, "message"}, :from, state)

      [{_, message, _, _}] = returned_state.messages
      assert message == "message"
    end

    test "returns not running message when target down", %{state: state} do
      alive_fn = fn _target -> false end

      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask, "@other> test"}, :from, %{state | alive_fn: alive_fn})

      assert response == "other is not running"
    end
  end

  describe "handle_call/2 :log" do
    test "returns messages from state" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: [{"type", "msg", "resp", %{}}]
      }

      {:reply, messages, _returned_state} = El.Session.handle_call(:log, :from, state)

      assert messages == [{"type", "msg", "resp", %{}}]
    end

    test "returns state unchanged" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: []
      }

      {:reply, _messages, returned_state} = El.Session.handle_call(:log, :from, state)

      assert returned_state == state
    end

    test "returns empty list when no messages" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: []
      }

      {:reply, messages, _returned_state} = El.Session.handle_call(:log, :from, state)

      assert messages == []
    end
  end

  describe "handle_call/2 :ask_tell" do
    test "returns route message when target running", %{state: state} do
      alive_fn = fn
        :target -> true
        _ -> false
      end

      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert response == "-> target"
    end

    test "stores message when target running", %{state: state} do
      alive_fn = fn
        :target -> true
        _ -> false
      end

      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert length(returned_state.messages) == 1
    end

    test "returns not running message when target down", %{state: state} do
      alive_fn = fn _target -> false end

      {:reply, response, _returned_state} =
        El.Session.handle_call({:ask_tell, :missing, "message"}, :from, %{
          state
          | alive_fn: alive_fn
        })

      assert response == "missing is not running"
    end

    test "stores relay message" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: [],
        alive_fn: fn :target -> true end
      }

      {:reply, _response, returned_state} =
        El.Session.handle_call({:ask_tell, :target, "message"}, :from, state)

      assert length(returned_state.messages) == 1
    end
  end

  describe "handle_info/2" do
    test "clears claude_pid on EXIT from claude process" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: []
      }

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :mock_pid, :normal}, state)

      assert returned_state.claude_pid == nil
    end

    test "preserves state on EXIT from different pid" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: []
      }

      {:noreply, returned_state} =
        El.Session.handle_info({:EXIT, :other_pid, :normal}, state)

      assert returned_state == state
    end

    test "preserves state on unknown message" do
      state = %{
        name: :test_session,
        claude_pid: :mock_pid,
        messages: []
      }

      {:noreply, returned_state} = El.Session.handle_info(:unknown_message, state)

      assert returned_state == state
    end
  end
end
