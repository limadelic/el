defmodule El2elAskRouteTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  @tag timeout: 10000
  test "Ask route: message with @target>? is relayed, not sent to Claude" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_target"

    El.start(sender)
    El.start(target)

    assert El.Session.alive?(sender), "Sender should be alive"
    assert El.Session.alive?(target), "Target should be alive"

    message = "@#{target}> 1 + 1?"

    response = El.ask(sender, message)

    target_log = El.log(target)

    assert Enum.any?(target_log, fn {_type, msg, _response, _metadata} ->
             String.contains?(msg, "1 + 1")
           end),
           "Target log should contain routed message: #{inspect(target_log)}"

    assert is_binary(response), "Response should be a string from target"
  end

  @tag timeout: 10000
  test "Ask route: target not running returns error" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_missing"

    El.start(sender)

    message = "@#{target}> hello?"

    response = El.ask(sender, message)

    assert String.contains?(response, "is not running"),
           "Should return error when target not running: #{response}"
  end

  @tag timeout: 15000
  test "Ask route: self-route is filtered" do
    sender = :"dude_#{System.os_time()}_self"
    dummy = :"dude_#{System.os_time()}_dummy"

    El.start(sender)
    El.start(dummy)

    message = "@#{dummy}> what is 2+2?"

    response = El.ask(sender, message)

    dummy_log = El.log(dummy)

    assert Enum.any?(dummy_log, fn {_type, msg, _response, _metadata} ->
             String.contains?(msg, "what is 2+2")
           end),
           "Dummy should receive the ask route: #{inspect(dummy_log)}"

    assert is_binary(response), "Response should be a string"
  end
end
