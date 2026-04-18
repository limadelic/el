defmodule KillScenarioTest do
  use ExUnit.Case

  setup do
    # Clean daemon state
    File.rm(Path.expand("~/.el/daemon_node"))
    :ok
  rescue
    _ -> :ok
  end

  test "Kill scenario end-to-end" do
    el_path = "/Users/maykel.suarez/dev/self/el/el"

    # Step 1: Start daemon in background (spawn async)
    spawn(fn -> System.cmd("sh", ["-c", "#{el_path} dude &"]) end)
    Process.sleep(1000)

    # Step 2: List sessions (should show dude)
    {output1, _} = System.cmd("sh", ["-c", "#{el_path} ls"])
    assert output1 =~ "dude", "Expected 'dude' in initial ls output"

    # Step 3: Kill the session
    {_kill_out, _} = System.cmd("sh", ["-c", "#{el_path} dude kill"])
    Process.sleep(100)

    # Step 4: List again (should show (dude) — dead)
    {output2, _} = System.cmd("sh", ["-c", "#{el_path} ls"])
    assert output2 =~ "(dude)", "Expected '(dude)' in final ls output, got: #{output2}"
  end
end
