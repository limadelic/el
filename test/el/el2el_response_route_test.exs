defmodule El2elResponseRouteTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  @tag :skip
  @tag timeout: 15000
  test "Response route: Claude response with @target> is relayed" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_target"

    El.start(sender)
    El.start(target)

    assert El.Session.alive?(sender), "Sender should be alive"
    assert El.Session.alive?(target), "Target should be alive"

    message = "what's up"
    response = "@#{target}> you are out of your element"

    via_sender = {:via, Registry, {El.Registry, sender}}
    GenServer.cast(via_sender, {:store_tell, message, response})

    target_log = poll_for_relay(target, 40, 250)

    assert Enum.any?(target_log, fn {_type, msg, _response, _metadata} ->
             String.contains?(msg, "you are out of your element")
           end),
           "Target log should contain relayed message: #{inspect(target_log)}"
  end

  @tag :skip
  @tag timeout: 10000
  test "Response route: target not running returns error in log" do
    sender = :"dude_#{System.os_time()}_sender"
    target = :"dude_#{System.os_time()}_missing"

    El.start(sender)

    message = "what's up"
    response = "@#{target}> hello"

    via_sender = {:via, Registry, {El.Registry, sender}}
    GenServer.cast(via_sender, {:store_tell, message, response})

    sender_log = poll_for_relay(sender, 40, 250)

    assert Enum.any?(sender_log, fn {type, _msg, resp, _metadata} ->
             type == "relay" && String.contains?(resp, "is not running")
           end),
           "Sender log should contain error: #{inspect(sender_log)}"
  end

  defp poll_for_relay(name, retries, delay_ms) when retries > 0 do
    log = El.log(name)

    if Enum.any?(log, fn entry -> tuple_size(entry) == 4 end) do
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
