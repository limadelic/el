defmodule El.AgentDetector.Spec do
  use ExUnit.Case

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
      agent_dir = Path.join([".claude", "agents"])
      File.mkdir_p!(agent_dir)
      agent_file = Path.join(agent_dir, "liz.md")
      File.write!(agent_file, "")

      assert El.AgentDetector.exists?("liz")

      File.rm!(agent_file)
      File.rm_rf!(agent_dir)
    end

    test "returns false when agent file does not exist" do
      refute El.AgentDetector.exists?("nonexistent")
    end
  end

  describe "detect_agent/1" do
    test "returns name when agent exists" do
      home = System.get_env("HOME")
      agent_dir = Path.join([home, ".claude", "agents"])
      File.mkdir_p!(agent_dir)
      agent_file = Path.join(agent_dir, "kenny.md")
      File.write!(agent_file, "")

      assert El.AgentDetector.detect_agent("kenny") == "kenny"

      File.rm!(agent_file)
    end

    test "returns nil when agent does not exist" do
      assert El.AgentDetector.detect_agent("nonexistent") == nil
    end
  end
end
