defmodule El.Features.El2ElSpec do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "El.tell/2" do
    test "routes message to target session" do
      expect(El.MockSessionApi, :tell, fn :dude, "@donnie> test message" -> :ok end)
      assert El.tell(:dude, "@donnie> test message") == :ok
    end

    test "passes exact message to session" do
      expected_msg = "@donnie> you are out of your element"
      expect(El.MockSessionApi, :tell, fn :dude, ^expected_msg -> :ok end)
      assert El.tell(:dude, expected_msg) == :ok
    end

    test "returns ok" do
      stub(El.MockSessionApi, :tell, fn _, _ -> :ok end)
      result = El.tell(:dude, "message")
      assert result == :ok
    end
  end

  describe "El.ask/2" do
    test "sends ask to session" do
      expect(El.MockSessionApi, :ask, fn :dude, "1 + 1" -> "2" end)
      assert El.ask(:dude, "1 + 1") == "2"
    end

    test "returns response from session" do
      stub(El.MockSessionApi, :ask, fn _, _ -> "response text" end)
      response = El.ask(:dude, "question")
      assert response == "response text"
    end

    test "routes to target session in message" do
      expected_msg = "@donnie> what is your name?"
      expect(El.MockSessionApi, :ask, fn :dude, ^expected_msg -> "-> donnie" end)
      result = El.ask(:dude, expected_msg)
      assert String.contains?(result, "donnie")
    end
  end

  describe "El.log/1" do
    test "fetches log from session" do
      log_entry = {"tell", "message", "response", %{}}
      expect(El.MockSessionApi, :log, fn :dude -> [log_entry] end)
      log = El.log(:dude)
      assert log == [log_entry]
    end

    test "returns empty list when no messages" do
      stub(El.MockSessionApi, :log, fn _ -> [] end)
      log = El.log(:dude)
      assert log == []
    end

    test "returns multiple entries in order" do
      entries = [
        {"tell", "msg1", "resp1", %{}},
        {"ask", "msg2", "resp2", %{}},
        {"relay", "msg3", "resp3", %{}}
      ]
      stub(El.MockSessionApi, :log, fn _ -> entries end)
      log = El.log(:dude)
      assert log == entries
    end
  end

  describe "El.log/2" do
    test "delegates to session with name and count" do
      expect(El.MockSessionApi, :log, fn :dude, 5 -> :ok end)
      assert El.log(:dude, 5) == :ok
    end
  end
end
