defmodule El.CLI.AgentDetectorSpec do
  use ExUnit.Case

  describe "exists?/1" do
    test "returns true when agent file exists in project" do
      assert El.CLI.AgentDetector.exists?("kent") == true
    end

    test "returns true when agent file exists in global" do
      assert El.CLI.AgentDetector.exists?("arana") == true
    end

    test "returns false when agent file does not exist" do
      assert El.CLI.AgentDetector.exists?("nonexistent_agent") == false
    end
  end

  describe "detect_agent/1" do
    test "returns agent name when agent exists in project" do
      assert El.CLI.AgentDetector.detect_agent("kent") == "kent"
    end

    test "returns agent name when agent exists in global" do
      assert El.CLI.AgentDetector.detect_agent("arana") == "arana"
    end

    test "returns nil when agent does not exist" do
      assert El.CLI.AgentDetector.detect_agent("nonexistent_agent") == nil
    end
  end
end
