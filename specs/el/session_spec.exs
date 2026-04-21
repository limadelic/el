defmodule El.Session.Spec do
  use ExUnit.Case

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

    test "detects route with whitespace in payload" do
      assert El.Session.detect_routes("@donnie>   multiple words here") == [
               {:donnie, "multiple words here"}
             ]
    end

    test "ignores routes not at start of line" do
      assert El.Session.detect_routes("some text @donnie> payload") == []
    end

    test "handles multiline with mixed content" do
      text = """
      @donnie> message one
      some other text
      @walter> message two
      """

      assert El.Session.detect_routes(text) == [
               {:donnie, "message one"},
               {:walter, "message two"}
             ]
    end

    test "converts target to atom" do
      result = El.Session.detect_routes("@test_name> payload")
      assert [{:test_name, _}] = result
    end
  end

  describe "start_link/1" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "starts session and returns {:ok, pid}" do
      session = :test_start_link
      {:ok, pid} = El.Session.start_link(session)
      assert is_pid(pid)
      assert El.Session.alive?(session)
    end

    test "accepts {name, opts} tuple" do
      session = :test_tuple_start
      {:ok, pid} = El.Session.start_link({session, [model: "test-model"]})
      assert is_pid(pid)
      assert El.Session.alive?(session)
    end

    test "accepts name and opts separately" do
      session = :test_separate_opts
      {:ok, pid} = El.Session.start_link(session, [model: "test-model"])
      assert is_pid(pid)
      assert El.Session.alive?(session)
    end
  end

  describe "alive?/1" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "returns true for running session" do
      session = :test_alive
      {:ok, _} = El.Session.start_link(session)
      assert El.Session.alive?(session)
    end

    test "returns false for non-existent session" do
      refute El.Session.alive?(:nonexistent_session_xyz)
    end
  end

  describe "log/1" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "returns empty list for new session" do
      session = :test_log_empty
      {:ok, _} = El.Session.start_link(session)
      messages = El.Session.log(session)
      assert messages == []
    end

    test "stores tell as 4-element tuple with empty metadata" do
      session = :test_tell_session
      {:ok, _pid} = El.Session.start_link(session)

      via = {:via, Registry, {El.Registry, session}}
      GenServer.cast(via, {:store_tell, "hello", "response"})

      Process.sleep(100)
      messages = El.Session.log(session)
      assert length(messages) == 1
      [{type, message, response, metadata}] = messages

      assert type == "tell"
      assert message == "hello"
      assert response == "response"
      assert metadata == %{}
    end

    test "stores relay messages with from metadata" do
      session = :test_relay_session
      {:ok, _pid} = El.Session.start_link(session)

      via = {:via, Registry, {El.Registry, session}}
      GenServer.cast(via, {:store_relay, "message", "response"})

      Process.sleep(100)
      messages = El.Session.log(session)
      assert length(messages) == 1
      [{type, _message, _response, metadata}] = messages

      assert type == "relay"
      assert is_map(metadata)
    end

    test "appends multiple messages in order" do
      session = :test_multi_message
      {:ok, _pid} = El.Session.start_link(session)

      via = {:via, Registry, {El.Registry, session}}
      GenServer.cast(via, {:store_tell, "msg1", "resp1"})
      GenServer.cast(via, {:store_tell, "msg2", "resp2"})

      Process.sleep(100)
      messages = El.Session.log(session)
      assert length(messages) == 2
      assert Enum.all?(messages, fn msg -> tuple_size(msg) == 4 end)
    end
  end

  describe "ask/2" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "returns a binary response" do
      session = :test_ask_response
      {:ok, _} = El.Session.start_link(session)

      response = El.Session.ask(session, "test question")
      assert is_binary(response)
    end

    test "stores ask in log" do
      session = :test_ask_log
      {:ok, _} = El.Session.start_link(session)

      message = "what is 2+2?"
      _response = El.Session.ask(session, message)

      messages = El.Session.log(session)
      assert Enum.any?(messages, fn {type, msg, _, _} ->
        type == "ask" && msg == message
      end)
    end

    test "handles long timeout" do
      session = :test_ask_timeout
      {:ok, _} = El.Session.start_link(session)

      response = El.Session.ask(session, "test")
      assert is_binary(response)
    end
  end

  describe "tell/2" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "tell returns :ok" do
      session = :test_tell_ok
      {:ok, _} = El.Session.start_link(session)

      result = El.Session.tell(session, "hello")
      assert result == :ok
    end
  end

  describe "tell_ask/3" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "tell_ask returns :ok" do
      target = :test_target
      sender = :test_sender
      {:ok, _} = El.Session.start_link(target)
      {:ok, _} = El.Session.start_link(sender)

      result = El.Session.tell_ask(sender, target, "message")
      assert result == :ok
    end
  end

  describe "ask_tell/3" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "ask_tell returns a binary response" do
      target = :test_ask_tell_target
      sender = :test_ask_tell_sender
      {:ok, _} = El.Session.start_link(target)
      {:ok, _} = El.Session.start_link(sender)

      response = El.Session.ask_tell(sender, target, "message")
      assert is_binary(response)
    end
  end

  describe "message tuple structure" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "all stored messages are 4-element tuples" do
      session = :test_msg_structure
      {:ok, _} = El.Session.start_link(session)

      via = {:via, Registry, {El.Registry, session}}
      GenServer.cast(via, {:store_tell, "msg1", "resp1"})

      messages = El.Session.log(session)

      Enum.each(messages, fn msg ->
        assert tuple_size(msg) == 4
        {type, _message, _response, metadata} = msg
        assert type in ["tell", "ask", "relay"]
        assert is_map(metadata)
      end)
    end
  end
end
