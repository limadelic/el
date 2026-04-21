defmodule El2elScenarioTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  @tag timeout: 10000
  test "Scenario: Ask route to another session" do
    dude = :dude_ask_route
    donnie = :donnie_ask_route

    El.start(dude)
    El.start(donnie)

    message = "@donnie_ask_route> 1 + 1?"

    response = El.ask(dude, message)

    assert response == "-> donnie_ask_route"

    donnie_log = poll_for_message(donnie, "1 + 1?", 20, 250)

    assert Enum.any?(donnie_log, fn {_type, msg, _response, _metadata} ->
             String.contains?(msg, "1 + 1?")
           end),
           "Donnie log should contain message: #{inspect(donnie_log)}"
  end

  @tag timeout: 10000
  test "Scenario: Tell route to another session" do
    dude = :dude_tell_route
    donnie = :donnie_tell_route

    El.start(dude)
    El.start(donnie)

    message = "@donnie_tell_route> you are out of your element"

    El.tell(dude, message)

    donnie_log = poll_for_message(donnie, "you are out of your element", 20, 250)

    assert Enum.any?(donnie_log, fn {_type, msg, _response, _metadata} ->
             String.contains?(msg, "you are out of your element")
           end),
           "Donnie log should contain message: #{inspect(donnie_log)}"
  end


  defp poll_for_message(name, content, retries, delay_ms) when retries > 0 do
    log = El.log(name)

    if Enum.any?(log, fn {_type, msg, _resp, _meta} -> String.contains?(msg, content) end) do
      log
    else
      Process.sleep(delay_ms)
      poll_for_message(name, content, retries - 1, delay_ms)
    end
  end

  defp poll_for_message(name, _content, 0, _delay_ms) do
    El.log(name)
  end
end
