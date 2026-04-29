defmodule El.AgentDetector.Spec do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!

  describe "El.AgentDetector.exists?/2" do
    test "returns true when global agent file exists" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "kent.md")
      end)

      assert El.AgentDetector.exists?("kent", El.MockFileSystem)
    end

    test "returns true when local agent file exists" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "liz.md")
      end)

      assert El.AgentDetector.exists?("liz", El.MockFileSystem)
    end

    test "returns false when agent file does not exist" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      refute El.AgentDetector.exists?("nonexistent", El.MockFileSystem)
    end
  end

  describe "El.AgentDetector.detect_agent/2" do
    test "returns name when agent exists" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "kenny.md")
      end)

      assert El.AgentDetector.detect_agent("kenny", El.MockFileSystem) == "kenny"
    end

    test "returns nil when agent does not exist" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      assert El.AgentDetector.detect_agent("nonexistent", El.MockFileSystem) == nil
    end
  end
end
