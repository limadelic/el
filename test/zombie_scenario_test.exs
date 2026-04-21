defmodule ZombieScenarioTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:el)
    :ok
  end

  test "Zombie scenario: Kill zombie session" do
    name = :zombie

    # Step 1: Start zombie session
    El.start(name)
    assert El.Session.alive?(name), "Session should be alive after start"

    # Step 2: List should show zombie
    sessions = El.ls()
    assert name in sessions, "Session should appear in ls: #{inspect(sessions)}"

    # Step 3: Kill the session
    :ok = El.kill(name)
    Process.sleep(100)
    refute El.Session.alive?(name), "Session should be dead after kill"

    # Step 4: List should not show dead session anymore
    sessions_after = El.ls()

    refute name in sessions_after,
           "Dead session should not appear in ls: #{inspect(sessions_after)}"
  end
end
