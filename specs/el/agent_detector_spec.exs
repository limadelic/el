defmodule El.AgentDetector.Spec do
  use ExUnit.Case

  setup do
    on_exit(fn -> File.rm_rf!(".claude/agents") end)
    :ok
  end

  describe "exists?/1" do
    test "returns true when global agent file exists" do
      home = System.get_env("HOME")
      agent_dir = Path.join([home, ".claude", "agents"])
      File.mkdir_p!(agent_dir)
      agent_file = Path.join(agent_dir, "kent.md")
      File.write!(agent_file, "")

      assert El.AgentDetector.exists?("kent")

      File.rm!(agent_file)
    end

    test "returns true when local agent file exists" do
      File.mkdir_p!(".claude/agents")
      File.write!(".claude/agents/liz.md", "")

      assert El.AgentDetector.exists?("liz")
    end

    test "returns false when agent file does not exist" do
      refute El.AgentDetector.exists?("nonexistent")
    end
  end

  describe "detect_agent/1" do
    test "returns name when agent exists" do
      File.mkdir_p!(".claude/agents")
      File.write!(".claude/agents/kenny.md", "")

      assert El.AgentDetector.detect_agent("kenny") == "kenny"
    end

    test "returns nil when agent does not exist" do
      assert El.AgentDetector.detect_agent("nonexistent") == nil
    end
  end
end
