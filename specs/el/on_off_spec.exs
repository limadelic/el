defmodule El.Features.OnOffSpec do
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
      El.kill(:duder)
      El.kill(:dudito)
      :dets.close(:message_store)
    end)

    :ok
  end

  describe "Session lifecycle" do
    test "single session starts and stops" do
      assert Enum.empty?(El.ls())

      El.start(:dude, claude_module: TestClaudeCode)
      assert Enum.member?(El.ls(), :dude)

      El.kill(:dude)
      assert !Enum.member?(El.ls(), :dude)
    end

    test "multiple sessions can run concurrently" do
      assert Enum.empty?(El.ls())

      El.start(:dude, claude_module: TestClaudeCode)
      El.start(:duder, claude_module: TestClaudeCode)
      El.start(:dudito, claude_module: TestClaudeCode)

      sessions = El.ls()
      assert Enum.member?(sessions, :dude)
      assert Enum.member?(sessions, :duder)
      assert Enum.member?(sessions, :dudito)
      assert length(sessions) == 3

      El.kill(:dude)
      El.kill(:duder)
      El.kill(:dudito)

      sessions = El.ls()
      assert Enum.empty?(sessions)
    end
  end
end
