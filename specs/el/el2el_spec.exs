defmodule El.Features.El2ElSpec do
  use ExUnit.Case

  setup_all do
    Supervisor.start_link(
      [
        {Registry, keys: :unique, name: El.Registry},
        {DynamicSupervisor, name: El.SessionSupervisor, max_restarts: 10, max_seconds: 30}
      ],
      strategy: :one_for_one,
      name: El.Supervisor
    )

    :ok
  end

  setup do
    El.Application.init_message_store()
    :dets.delete_all_objects(:message_store)

    on_exit(fn ->
      El.kill(:dude)
      El.kill(:donnie)
      :dets.close(:message_store)
    end)

    :ok
  end

  describe "El2El routing" do
    test "tell routes message to another session" do
      El.start(:dude, claude_module: TestClaudeCode)
      El.start(:donnie, claude_module: TestClaudeCode)

      El.tell(:dude, "@donnie> you are out of your element")

      assert_eventually(fn ->
        log = El.log(:donnie)
        Enum.any?(log, fn {type, msg, _, _} ->
          type == "relay" && String.contains?(msg, "you are out of your element")
        end)
      end)
    end

    test "ask routes to another session returns confirmation" do
      El.start(:dude, claude_module: TestClaudeCode)
      El.start(:donnie, claude_module: TestClaudeCode)

      response = El.ask(:dude, "@donnie> 1 + 1")

      assert String.contains?(response, "donnie")
    end
  end

  defp assert_eventually(assertion_fn, timeout_ms \\ 5000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    try do
      assertion_fn.()
    rescue
      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(100)
          assert_eventually(assertion_fn, timeout_ms)
        else
          raise "Assertion timed out"
        end
    end
  end
end
