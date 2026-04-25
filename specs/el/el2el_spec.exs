defmodule El.Features.El2ElSpec do
  use ExUnit.Case

  setup do
    Mimic.copy(El.Session)
    :ok
  end

  describe "El.tell/2" do
    test "routes message to target session" do
      Mimic.expect(El.Session, :tell, fn :dude, "@donnie> test message" ->
        :ok
      end)

      El.tell(:dude, "@donnie> test message")
    end

    test "passes exact message to session" do
      expected_msg = "@donnie> you are out of your element"

      Mimic.expect(El.Session, :tell, fn :dude, ^expected_msg ->
        :ok
      end)

      El.tell(:dude, expected_msg)
    end

    test "returns ok" do
      Mimic.stub(El.Session, :tell, fn _, _ -> :ok end)

      result = El.tell(:dude, "message")
      assert result == :ok
    end
  end

  describe "El.ask/2" do
    test "sends ask to session" do
      Mimic.expect(El.Session, :ask, fn :dude, "1 + 1" ->
        "2"
      end)

      El.ask(:dude, "1 + 1")
    end

    test "returns response from session" do
      Mimic.stub(El.Session, :ask, fn _, _ -> "response text" end)

      response = El.ask(:dude, "question")
      assert response == "response text"
    end

    test "routes to target session in message" do
      expected_msg = "@donnie> what is your name?"

      Mimic.expect(El.Session, :ask, fn :dude, ^expected_msg ->
        "-> donnie"
      end)

      result = El.ask(:dude, expected_msg)
      assert String.contains?(result, "donnie")
    end
  end

  describe "El.log/1" do
    test "fetches log from session" do
      log_entry = {"tell", "message", "response", %{}}

      Mimic.expect(El.Session, :log, fn :dude ->
        [log_entry]
      end)

      log = El.log(:dude)
      assert log == [log_entry]
    end

    test "returns empty list when no messages" do
      Mimic.stub(El.Session, :log, fn _ -> [] end)

      log = El.log(:dude)
      assert log == []
    end

    test "returns multiple entries in order" do
      entries = [
        {"tell", "msg1", "resp1", %{}},
        {"ask", "msg2", "resp2", %{}},
        {"relay", "msg3", "resp3", %{}}
      ]

      Mimic.stub(El.Session, :log, fn _ -> entries end)

      log = El.log(:dude)
      assert log == entries
    end
  end

  describe "El.log/2" do
    test "delegates to session with name and count" do
      Mimic.expect(El.Session, :log, fn :dude, 5 ->
        :ok
      end)

      El.log(:dude, 5)
    end
  end
end
