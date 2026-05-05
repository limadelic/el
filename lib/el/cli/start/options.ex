defmodule El.CLI.Start.Options do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def agent_opt(nil), do: []
  def agent_opt(agent), do: [agent: agent]

  def agent_model_for(nil), do: []
  def agent_model_for(model), do: [model: model]

  def agent_detector(deps) do
    Keyword.get(deps, :agent_detector, El.AgentDetector)
  end

  def agent_metadata(deps) do
    Keyword.get(deps, :agent_metadata, El.AgentMetadata)
  end

  def subagent_model(nil), do: []
  def subagent_model(model), do: [model: model]
end
