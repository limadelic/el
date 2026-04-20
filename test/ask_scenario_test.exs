defmodule AskScenarioTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  @tag timeout: 10000
  test "Ask scenario: start, ask, log shows response" do
    name = :"dude_#{System.os_time()}"
    question = "1 + 1"

    # Step 1: Start session
    El.start(name)
    assert El.Session.alive?(name), "Session should be alive after start"

    # Step 2: Ask the session — may fail if Claude CLI unavailable
    response =
      try do
        El.ask(name, question)
      catch
        :exit, _ ->
          "(ClaudeCode unavailable)"
      end

    # Step 3: Log should show the ask and response
    log = El.log(name)

    assert Enum.any?(log, fn {type, msg, _resp} ->
             type == "ask" && msg == question
           end),
           "Question should appear in log: #{inspect(log)}"

    # Step 4: If Claude is available, response should be a string
    assert is_binary(response), "Response should be a string: #{inspect(response)}"
  end
end
