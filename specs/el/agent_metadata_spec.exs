defmodule El.AgentMetadata.Spec do
  use ExUnit.Case

  setup do
    fixture_dir = Path.expand("../fixtures", __DIR__)
    File.mkdir_p!(fixture_dir)
    on_exit(fn -> File.rm_rf!(fixture_dir) end)
    {:ok, fixture_dir: fixture_dir}
  end

  describe "El.AgentMetadata.model_for/1" do
    test "returns model from frontmatter with atom name", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "kent.md")
      File.write!(agent_file, "---\nmodel: opus\n---\n# Kent\n")

      assert El.AgentMetadata.model_for(:kent, fixture_dir) == "opus"
    end

    test "returns model from frontmatter with string name", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "liz.md")
      File.write!(agent_file, "---\nmodel: sonnet\n---\n# Liz\n")

      assert El.AgentMetadata.model_for("liz", fixture_dir) == "sonnet"
    end

    test "returns nil when file does not exist", %{fixture_dir: fixture_dir} do
      assert El.AgentMetadata.model_for("nonexistent", fixture_dir) == nil
    end

    test "returns nil when no frontmatter", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "bob.md")
      File.write!(agent_file, "# Bob\nNo frontmatter here\n")

      assert El.AgentMetadata.model_for("bob", fixture_dir) == nil
    end

    test "returns nil when no model field in frontmatter", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "cartman.md")
      File.write!(agent_file, "---\nname: cartman\n---\n# Cartman\n")

      assert El.AgentMetadata.model_for("cartman", fixture_dir) == nil
    end

    test "returns nil when frontmatter incomplete", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "kenny.md")
      File.write!(agent_file, "---\nmodel: haiku")

      assert El.AgentMetadata.model_for("kenny", fixture_dir) == nil
    end

    test "parses model with extra whitespace", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "lisa.md")
      File.write!(agent_file, "---\nmodel:  sonnet  \n---\n# Lisa\n")

      assert El.AgentMetadata.model_for("lisa", fixture_dir) == "sonnet"
    end

    test "falls back to local path when no search_dir provided", %{fixture_dir: fixture_dir} do
      local_file = Path.join([fixture_dir, ".claude", "agents", "lisa.md"])
      File.mkdir_p!(Path.dirname(local_file))
      File.write!(local_file, "---\nmodel: sonnet\n---\n# Lisa\n")

      cwd = File.cwd!()
      File.cd!(fixture_dir)

      try do
        assert El.AgentMetadata.model_for("lisa") == "sonnet"
      after
        File.cd!(cwd)
      end
    end
  end
end
