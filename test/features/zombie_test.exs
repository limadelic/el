defmodule ZombieTest do
  use Cabbage.Feature, async: false, file: "zombie.feature"

  setup do
    File.rm(Path.expand("~/.el/daemon_node"))
    :ok
  rescue
    _ -> :ok
  end

  defwhen ~r/^I run el (.+) in background$/, _, state do
    el_path = System.get_env("MIX_ESCRIPT_PATH") || "el"
    System.cmd("sh", ["-c", "#{el_path} dude &"], stderr_to_stdout: true)
    Process.sleep(500)
    state
  end

  defwhen ~r/^I run el (.+) kill$/, _, state do
    el_path = System.get_env("MIX_ESCRIPT_PATH") || "el"
    System.cmd("sh", ["-c", "#{el_path} dude kill"], stderr_to_stdout: true)
    state
  end

  defthen ~r/^el ls should show (?<expected>.+)$/, %{"expected" => expected}, _s do
    el_path = System.get_env("MIX_ESCRIPT_PATH") || "el"
    {output, _status} = System.cmd("sh", ["-c", "#{el_path} ls"], stderr_to_stdout: true)
    assert output =~ expected, "Expected '#{expected}' in output:\n#{output}"
  end
end
