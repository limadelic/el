defmodule El2elTellAskTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  @tag timeout: 10000
  test "Tell ask cross route: sender tells, target asks Claude" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_target"

    El.start(sender)
    El.start(target)

    assert El.Session.alive?(sender), "Sender should be alive"
    assert El.Session.alive?(target), "Target should be alive"

    El.tell_ask(sender, target, "1 + 1")

    :timer.sleep(500)

    target_log = El.log(target)

    assert Enum.any?(target_log, fn {type, msg, _response, metadata} ->
             type == "ask" && String.contains?(msg, "1 + 1") &&
               String.contains?(msg, "[from #{sender}]") &&
               metadata[:from] == nil
           end),
           "Target should have ask with [from sender] prefix: #{inspect(target_log)}"
  end

  @tag timeout: 10000
  test "Tell ask cross route: target not running doesn't crash" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_missing"

    El.start(sender)

    El.tell_ask(sender, target, "1 + 1")

    :timer.sleep(500)

    sender_log = El.log(sender)

    assert Enum.any?(sender_log, fn {type, msg, response, metadata} ->
             type == "relay" && String.contains?(msg, "1 + 1") &&
               String.contains?(response, "is not running") &&
               metadata[:from] == sender
           end),
           "Sender should log relay error: #{inspect(sender_log)}"
  end
end
