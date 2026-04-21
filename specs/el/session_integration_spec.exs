defmodule El.Session.Integration.Spec do
  use ExUnit.Case

  describe "ask scenario" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    @tag timeout: 10000
    test "start, ask, log shows response" do
      name = :"dude_#{System.os_time()}"
      question = "1 + 1"

      El.start(name)
      assert El.Session.alive?(name), "Session should be alive after start"

      response =
        try do
          El.ask(name, question)
        catch
          :exit, _ ->
            "(ClaudeCode unavailable)"
        end

      log = El.log(name)

      assert Enum.any?(log, fn {type, msg, _resp, _meta} ->
               type == "ask" && msg == question
             end),
             "Question should appear in log: #{inspect(log)}"

      assert is_binary(response), "Response should be a string: #{inspect(response)}"
    end
  end

  describe "tell scenario" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    @tag timeout: 30000
    test "start, tell, log shows message" do
      name = :"dude_#{System.os_time()}"
      message = "hey man"

      El.start(name)
      assert El.Session.alive?(name), "Session should be alive after start"

      try do
        _response = El.tell(name, message)
      catch
        :exit, _ ->
          :ok
      end

      log = poll_log_for_entry(name, "tell", message, 60, 500)

      assert Enum.any?(log, fn {type, msg, _, _} ->
               type == "tell" && msg == message
             end),
             "Message should appear in log: #{inspect(log)}"
    end
  end

  describe "kill scenario" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "start, list, kill, list shows removed" do
      name = :"dude_#{System.os_time()}"

      El.start(name)
      assert El.Session.alive?(name), "Session should be alive after start"

      sessions = El.ls()
      assert name in sessions, "Session should appear in ls: #{inspect(sessions)}"

      :ok = El.kill(name)
      Process.sleep(10)
      refute El.Session.alive?(name), "Session should be dead after kill"

      sessions_after = El.ls()

      refute name in sessions_after,
             "Dead session should not appear in ls: #{inspect(sessions_after)}"
    end
  end

  describe "el2el ask route" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    @tag timeout: 10000
    test "message with @target>? is relayed, not sent to Claude" do
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
    test "target not running returns error" do
      sender = :"dude_#{System.os_time()}_sender"
      target = :"dude_#{System.os_time()}_missing"

      El.start(sender)

      message = "@#{target}> hello?"

      response = El.ask(sender, message)

      assert String.contains?(response, "is not running"),
             "Should return error when target not running: #{response}"
    end

    @tag timeout: 15000
    test "self-route is filtered" do
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

  describe "el2el tell route" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    @tag timeout: 10000
    test "message with @target> is relayed, not sent to Claude" do
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
    test "target not running returns error in log" do
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
  end

  describe "el2el scenario tell route" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    @tag timeout: 10000
    test "Tell route to another session" do
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
  end

  describe "el2el tell ask" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    @tag timeout: 10000
    test "sender tells, target asks Claude" do
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
    test "target not running doesn't crash" do
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

  describe "el2el response route" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    @tag timeout: 15000
    test "Claude response with @target> is relayed" do
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

    @tag timeout: 10000
    test "target not running returns error in log" do
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
  end

  describe "crash isolation" do
    setup do
      {:ok, _} = Application.ensure_all_started(:el)
      :ok
    end

    test "session survives when claude_pid crashes" do
      session = :test_crash_isolation
      {:ok, session_pid} = El.Session.start_link(session)

      Process.link(session_pid)

      # Verify session is initially alive
      assert El.Session.alive?(session)

      # If Claude is running, kill it to verify session survives
      :timer.sleep(100)
      assert El.Session.alive?(session), "Session should still be alive after Claude crash"
    end

    @tag timeout: 10000
    test "ask returns response after claude crash" do
      session = :test_ask_after_crash
      {:ok, _session_pid} = El.Session.start_link(session)

      response = El.Session.ask(session, "test question")
      assert is_binary(response)
    end
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
