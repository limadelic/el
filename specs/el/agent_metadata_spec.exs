defmodule El.AgentMetadata.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.AgentMetadata)
    Code.ensure_loaded!(El.Agent.Paths)
    :ok
  end

  setup do
    fixture_dir = Path.expand("../fixtures", __DIR__)
    File.mkdir_p!(fixture_dir)
    on_exit(fn -> File.rm_rf!(fixture_dir) end)
    {:ok, fixture_dir: fixture_dir}
  end

  describe "El.AgentMetadata.model_for/2" do
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

    test "searches in provided search_dir for agent file", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "lisa.md")
      File.write!(agent_file, "---\nmodel: sonnet\n---\n# Lisa\n")

      assert El.AgentMetadata.model_for("lisa", fixture_dir) == "sonnet"
    end
  end

  describe "El.AgentMetadata.model_for/1" do
    test "returns model from local path when present", %{fixture_dir: fixture_dir} do
      local_dir = Path.join(fixture_dir, ".claude/agents")
      File.mkdir_p!(local_dir)
      local_file = Path.join(local_dir, "eric.md")
      File.write!(local_file, "---\nmodel: sonnet\n---\n# Eric\n")

      File.cd!(fixture_dir, fn ->
        assert El.AgentMetadata.model_for("eric") == "sonnet"
      end)
    end

    test "returns model from global path when local missing", %{fixture_dir: fixture_dir} do
      home = System.get_env("HOME")
      global_dir = Path.join(home, ".claude/agents")
      File.mkdir_p!(global_dir)
      global_file = Path.join(global_dir, "dude.md")
      File.write!(global_file, "---\nmodel: opus\n---\n# Dude\n")

      File.cd!(fixture_dir, fn ->
        assert El.AgentMetadata.model_for("dude") == "opus"
      end)
    end
  end
end
