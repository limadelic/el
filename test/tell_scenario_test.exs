defmodule TellScenarioTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  @tag timeout: 10000
  test "Tell scenario: start, tell, log shows message" do
    name = :"dude_#{System.os_time()}"
    message = "hey man"

    # Step 1: Start session
    El.start(name)
    assert El.Session.alive?(name), "Session should be alive after start"

    # Step 2: Tell the session — may fail if Claude CLI unavailable
    # Just verify the call completes (successful or error)
    try do
      _response = El.tell(name, message)
    catch
      :exit, _ ->
        # ClaudeCode initialization failed (expected in test env without CLI)
        :ok
    end

    # Step 3: Log should show the message attempt was recorded
    log = El.log(name)

    assert Enum.any?(log, fn {type, msg, _} ->
             type == "tell" && msg == message
           end),
           "Message should appear in log: #{inspect(log)}"
  end
end
