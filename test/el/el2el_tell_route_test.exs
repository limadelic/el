defmodule El2elTellRouteTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  @tag timeout: 10000
  test "Tell route: message with @target> is relayed, not sent to Claude" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_target"

    El.start(sender)
    El.start(target)

    assert El.Session.alive?(sender), "Sender should be alive"
    assert El.Session.alive?(target), "Target should be alive"

    message = "@#{target}> you are out of your element"

    El.tell(sender, message)

    target_log = poll_for_relay(target, 20, 250)

    assert Enum.any?(target_log, fn {_type, msg, _response, _metadata} ->
             String.contains?(msg, "you are out of your element")
           end),
           "Target log should contain relayed message: #{inspect(target_log)}"
  end

  @tag timeout: 10000
  test "Tell route: target not running returns error in log" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_missing"

    El.start(sender)

    message = "@#{target}> hello"

    El.tell(sender, message)

    sender_log = poll_for_relay(sender, 20, 250)

    assert Enum.any?(sender_log, fn {type, _msg, response, _metadata} ->
             type == "relay" && String.contains?(response, "is not running")
           end),
           "Sender log should contain error: #{inspect(sender_log)}"
  end

  defp poll_for_relay(name, retries, delay_ms) when retries > 0 do
    log = El.log(name)

    if Enum.any?(log, fn {type, _msg, _resp, _meta} -> type == "relay" end) do
      log
    else
      Process.sleep(delay_ms)
      poll_for_relay(name, retries - 1, delay_ms)
    end
  end

  defp poll_for_relay(name, 0, _delay_ms) do
    El.log(name)
  end
end
