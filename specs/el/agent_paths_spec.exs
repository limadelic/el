defmodule El.Agent.Paths.Spec do
  use ExUnit.Case

  describe "El.Agent.Paths.local_path/1" do
    test "returns relative path in .claude/agents directory" do
      path = El.Agent.Paths.local_path("kent")
      assert path == Path.join([".claude", "agents", "kent.md"])
    end

    test "handles different agent names" do
      path = El.Agent.Paths.local_path("liz")
      assert path == Path.join([".claude", "agents", "liz.md"])
    end
  end

  describe "El.Agent.Paths.global_path/1" do
    test "returns expanded home path in .claude/agents directory" do
      home = System.get_env("HOME")
      path = El.Agent.Paths.global_path("kent")
      assert path == Path.join([home, ".claude", "agents", "kent.md"])
    end

    test "handles different agent names" do
      home = System.get_env("HOME")
      path = El.Agent.Paths.global_path("liz")
      assert path == Path.join([home, ".claude", "agents", "liz.md"])
    end
  end
end
