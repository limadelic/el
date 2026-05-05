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

  describe "El.CLI.Start.Options.env_model/2" do
    test "returns model from env when opts has neither :model nor :agent" do
      stub(El.MockEnv, :get, fn _ -> "from-env" end)
      deps = [env: El.MockEnv]
      assert El.CLI.Start.Options.env_model([], deps) == [model: "from-env"]
    end
  end

  describe "El.CLI.Start.Options.resolve_agent/3" do
    test "returns explicit agent unchanged when not nil" do
      deps = [agent_detector: El.MockAgentDetector]
      assert El.CLI.Start.Options.resolve_agent(:explicit, "name", deps) == :explicit
    end

    test "delegates to agent_detector when explicit is nil" do
      expect(El.MockAgentDetector, :detect_agent, fn "name" -> :detected end)
      deps = [agent_detector: El.MockAgentDetector]
      assert El.CLI.Start.Options.resolve_agent(nil, "name", deps) == :detected
    end
  end

  describe "El.CLI.Start.Options.build_base_opts/3" do
    test "composes start_opts ++ agent_opt ++ agent_model_opt in order" do
      stub(El.MockAgentMetadata, :model_for, fn "kent" -> "opus" end)
      deps = [agent_metadata: El.MockAgentMetadata]
      assert El.CLI.Start.Options.build_base_opts(nil, "kent", deps) == [agent: "kent", model: "opus"]
    end
  end

  describe "El.CLI.Start.Options.detect_and_merge_agent/3" do
    setup do
      System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      :ok
    end

    test "detects agent through injected detector" do
      expect(El.MockAgentDetector, :detect_agent, fn "kent" -> "kent" end)
      deps = [agent_detector: El.MockAgentDetector]
      result = El.CLI.Start.Options.detect_and_merge_agent("kent", [], deps)

      assert Keyword.get(result, :agent) == "kent"
    end

    test "includes opts in result" do
      expect(El.MockAgentDetector, :detect_agent, fn "session" -> nil end)
      stub(El.MockEnv, :get, fn _ -> nil end)
      deps = [agent_detector: El.MockAgentDetector, env: El.MockEnv]
      result = El.CLI.Start.Options.detect_and_merge_agent("session", [model: "haiku"], deps)

      assert Keyword.get(result, :model) == "haiku"
    end

    test "handles nil agent from detector" do
      expect(El.MockAgentDetector, :detect_agent, fn "session" -> nil end)
      stub(El.MockEnv, :get, fn _ -> nil end)
      deps = [agent_detector: El.MockAgentDetector, env: El.MockEnv]
      result = El.CLI.Start.Options.detect_and_merge_agent("session", [], deps)

      refute Keyword.has_key?(result, :agent)
    end
  end
end
