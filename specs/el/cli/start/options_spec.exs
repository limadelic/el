defmodule El.CLI.Start.Options.Spec do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  describe "El.CLI.Start.Options.start_opts/1" do
    test "returns empty list when model is nil" do
      assert El.CLI.Start.Options.start_opts(nil) == []
    end

    test "returns model kwarg when model provided" do
      assert El.CLI.Start.Options.start_opts("haiku") == [model: "haiku"]
    end
  end

  describe "El.CLI.Start.Options.normalize_model/1" do
    test "returns nil when model is empty string" do
      assert El.CLI.Start.Options.normalize_model("") == nil
    end

    test "returns model when non-empty string" do
      assert El.CLI.Start.Options.normalize_model("opus") == "opus"
    end
  end

  describe "El.CLI.Start.Options.agent_opt/1" do
    test "returns empty list when agent is nil" do
      assert El.CLI.Start.Options.agent_opt(nil) == []
    end

    test "returns agent kwarg when agent provided" do
      assert El.CLI.Start.Options.agent_opt("kent") == [agent: "kent"]
    end
  end

  describe "El.CLI.Start.Options.agent_model_for/1" do
    test "returns empty list when model is nil" do
      assert El.CLI.Start.Options.agent_model_for(nil) == []
    end

    test "returns model kwarg when model provided" do
      assert El.CLI.Start.Options.agent_model_for("opus") == [model: "opus"]
    end
  end

  describe "El.CLI.Start.Options.agent_detector/1" do
    test "returns default detector when not in deps" do
      detector = El.CLI.Start.Options.agent_detector([])
      assert detector == El.AgentDetector
    end

    test "returns custom detector from deps" do
      detector = El.CLI.Start.Options.agent_detector([agent_detector: CustomDetector])
      assert detector == CustomDetector
    end
  end

  describe "El.CLI.Start.Options.agent_metadata/1" do
    test "returns default metadata when not in deps" do
      metadata = El.CLI.Start.Options.agent_metadata([])
      assert metadata == El.AgentMetadata
    end

    test "returns custom metadata from deps" do
      metadata = El.CLI.Start.Options.agent_metadata([agent_metadata: CustomMetadata])
      assert metadata == CustomMetadata
    end
  end

  describe "El.CLI.Start.Options.subagent_model/1" do
    test "returns empty list when model is nil" do
      assert El.CLI.Start.Options.subagent_model(nil) == []
    end

    test "returns model kwarg when model provided" do
      assert El.CLI.Start.Options.subagent_model("haiku") == [model: "haiku"]
    end
  end

  describe "El.CLI.Start.Options.agent_model_opt/3" do
    setup do
      stub(El.MockAgentMetadata, :model_for, fn
        "kent" -> "opus"
        _ -> nil
      end)
      :ok
    end

    test "returns empty list when agent is nil" do
      assert El.CLI.Start.Options.agent_model_opt(nil, nil, []) == []
    end

    test "returns empty list when explicit model is provided" do
      assert El.CLI.Start.Options.agent_model_opt("kent", "sonnet", []) == []
    end

    test "resolves model from metadata when agent present and no explicit model" do
      deps = [agent_metadata: El.MockAgentMetadata]
      assert El.CLI.Start.Options.agent_model_opt("kent", nil, deps) == [model: "opus"]
    end

    test "returns empty list when agent has no model in metadata" do
      deps = [agent_metadata: El.MockAgentMetadata]
      assert El.CLI.Start.Options.agent_model_opt("unknown", nil, deps) == []
    end
  end

  describe "El.CLI.Start.Options.env_model_for/3" do
    setup do
      stub(El.MockEnv, :get, fn _ -> nil end)
      {:ok, deps: [env: El.MockEnv]}
    end

    test "returns empty list when model is set", %{deps: deps} do
      assert El.CLI.Start.Options.env_model_for("haiku", nil, deps) == []
    end

    test "returns empty list when agent is set", %{deps: deps} do
      assert El.CLI.Start.Options.env_model_for(nil, "kent", deps) == []
    end

    test "returns empty list when both model and agent are set", %{deps: deps} do
      assert El.CLI.Start.Options.env_model_for("haiku", "kent", deps) == []
    end

    test "reads CLAUDE_CODE_SUBAGENT_MODEL when model and agent are nil", %{deps: deps} do
      expect(El.MockEnv, :get, fn name ->
        if name == "CLAUDE_CODE_SUBAGENT_MODEL", do: "opus", else: nil
      end)
      assert El.CLI.Start.Options.env_model_for(nil, nil, deps) == [model: "opus"]
    end

    test "returns empty list when env var not set", %{deps: deps} do
      assert El.CLI.Start.Options.env_model_for(nil, nil, deps) == []
    end
  end
end
