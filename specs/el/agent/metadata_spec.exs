defmodule El.Agent.Metadata.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.Agent.Metadata)
    Code.ensure_loaded!(El.Agent.Paths)
    :ok
  end

  setup do
    fixture_dir = Path.expand("../fixtures", __DIR__)
    File.mkdir_p!(fixture_dir)
    on_exit(fn -> File.rm_rf!(fixture_dir) end)
    {:ok, fixture_dir: fixture_dir}
  end

  describe "El.Agent.Metadata.model_for/2" do
    test "returns model from frontmatter with atom name", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "kent.md")
      File.write!(agent_file, "---\nmodel: opus\n---\n# Kent\n")

      assert El.Agent.Metadata.model_for(:kent, fixture_dir) == "opus"
    end

    test "returns model from frontmatter with string name", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "liz.md")
      File.write!(agent_file, "---\nmodel: sonnet\n---\n# Liz\n")

      assert El.Agent.Metadata.model_for("liz", fixture_dir) == "sonnet"
    end

    test "returns nil when file does not exist", %{fixture_dir: fixture_dir} do
      assert El.Agent.Metadata.model_for("nonexistent", fixture_dir) == nil
    end

    test "returns nil when no frontmatter", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "bob.md")
      File.write!(agent_file, "# Bob\nNo frontmatter here\n")

      assert El.Agent.Metadata.model_for("bob", fixture_dir) == nil
    end

    test "returns nil when no model field in frontmatter", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "cartman.md")
      File.write!(agent_file, "---\nname: cartman\n---\n# Cartman\n")

      assert El.Agent.Metadata.model_for("cartman", fixture_dir) == nil
    end

    test "returns nil when frontmatter incomplete", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "kenny.md")
      File.write!(agent_file, "---\nmodel: haiku")

      assert El.Agent.Metadata.model_for("kenny", fixture_dir) == nil
    end

    test "parses model with extra whitespace", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "lisa.md")
      File.write!(agent_file, "---\nmodel:  sonnet  \n---\n# Lisa\n")

      assert El.Agent.Metadata.model_for("lisa", fixture_dir) == "sonnet"
    end

    test "searches in provided search_dir for agent file", %{fixture_dir: fixture_dir} do
      agent_file = Path.join(fixture_dir, "lisa.md")
      File.write!(agent_file, "---\nmodel: sonnet\n---\n# Lisa\n")

      assert El.Agent.Metadata.model_for("lisa", fixture_dir) == "sonnet"
    end
  end
end
