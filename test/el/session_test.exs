defmodule El.SessionTest do
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

  describe "message storage" do
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

    test "message tuple structure for ask" do
      session = :test_ask_structure
      {:ok, _pid} = El.Session.start_link(session)

      via = {:via, Registry, {El.Registry, session}}
      GenServer.call(via, {:ask, "test question"}, :infinity)

      messages = El.Session.log(session)
      assert length(messages) == 1
      [{type, message, response, metadata}] = messages

      assert type == "ask"
      assert message == "test question"
      assert is_binary(response)
      assert metadata == %{}
    end

    test "message tuples are 4-element" do
      session = :test_tuple_session
      {:ok, _pid} = El.Session.start_link(session)

      via = {:via, Registry, {El.Registry, session}}
      GenServer.cast(via, {:store_tell, "msg1", "resp1"})

      messages = El.Session.log(session)

      Enum.each(messages, fn msg ->
        assert tuple_size(msg) == 4
        {type, _message, _response, metadata} = msg
        assert type in ["tell", "ask"]
        assert is_map(metadata)
      end)
    end
  end
end
