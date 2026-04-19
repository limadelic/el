defmodule KillScenarioTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  test "Kill scenario: start, list, kill, list shows tombstone" do
    # Use unique name to avoid test isolation issues
    name = :"dude_#{System.os_time()}"

    # Step 1: Start session
    El.start(name)
    assert El.Session.alive?(name), "Session should be alive after start"

    # Step 2: List should show session
    sessions = El.ls()
    assert name in sessions, "Session should appear in ls: #{inspect(sessions)}"

    # Step 3: Kill the session
    :ok = El.kill(name)
    # Give it a moment to clean up
    Process.sleep(10)
    refute El.Session.alive?(name), "Session should be dead after kill"

    # Step 4: List should still show it (as dead/tombstone)
    sessions_after = El.ls()

    assert name in sessions_after,
           "Dead session should appear in tombstone ls: #{inspect(sessions_after)}"
  end
end
