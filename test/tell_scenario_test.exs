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
    try do
      _response = El.tell(name, message)
    catch
      :exit, _ ->
        :ok
    end

    # Step 3: Poll log until tell entry appears (tell is async via Task)
    log = poll_log_for_entry(name, "tell", message, 20, 250)

    assert Enum.any?(log, fn {type, msg, _, _} ->
             type == "tell" && msg == message
           end),
           "Message should appear in log: #{inspect(log)}"
  end

  defp poll_log_for_entry(name, type, message, retries, delay_ms) when retries > 0 do
    log = El.log(name)

    if Enum.any?(log, fn {t, msg, _, _} -> t == type && msg == message end) do
      log
    else
      Process.sleep(delay_ms)
      poll_log_for_entry(name, type, message, retries - 1, delay_ms)
    end
  end

  defp poll_log_for_entry(name, _type, _message, 0, _delay_ms) do
    El.log(name)
  end
end
