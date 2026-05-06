defmodule El.CLI.Start.Options do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def agent_opt(nil), do: []
  def agent_opt(agent), do: [agent: agent]

  def build_base_opts(explicit_model, agent, deps) do
    start_opts(explicit_model) ++
      agent_opt(agent) ++
      agent_model_opt(agent, explicit_model, deps)
  end

  def agent_model_for(nil), do: []
  def agent_model_for(model), do: [model: model]

  def agent_detector(deps) do
    Keyword.get(deps, :agent_detector, El.AgentDetector)
  end

  def resolve_agent(nil, name, deps), do: agent_detector(deps).detect_agent(name)
  def resolve_agent(agent, _name, _deps), do: agent

  def agent_metadata(deps) do
    Keyword.get(deps, :agent_metadata, El.AgentMetadata)
  end

  def subagent_model(nil), do: []
  def subagent_model(model), do: [model: model]

  def agent_model_opt(nil, _, _), do: []
  def agent_model_opt(_, explicit_model, _) when explicit_model != nil, do: []
  def agent_model_opt(agent, nil, deps) do
    metadata = agent_metadata(deps)
    agent_model_for(metadata.model_for(agent))
  end

  def env_model_for(nil, nil, deps) do
    env = env_adapter(deps)
    subagent_model(env.get("CLAUDE_CODE_SUBAGENT_MODEL"))
  end

  def env_model_for(_, _, _), do: []

  def env_model(opts, deps) do
    env_model_for(Keyword.get(opts, :model), Keyword.get(opts, :agent), deps)
  end

  defp env_adapter(deps) do
    Keyword.get(deps, :env, El.Env)
  end

  def detect_and_merge_agent(name, opts, deps \\ []) do
    merged = opts ++ agent_opt(agent_detector(deps).detect_agent(name))
    merged ++ env_model(merged, deps)
  end

  def merge_session_opts(name, explicit_agent \\ nil, explicit_model \\ nil, deps \\ []) do
    agent = resolve_agent(explicit_agent, name, deps)
    base = build_base_opts(explicit_model, agent, deps)
    base ++ env_model(base, deps)
  end
end
