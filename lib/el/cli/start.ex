defmodule El.CLI.Start do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def merge_session_opts(name, explicit_agent \\ nil, explicit_model \\ nil) do
    model_opts = start_opts(explicit_model)
    agent = explicit_agent || El.AgentDetector.detect_agent(name)
    agent_opts = agent_opt(agent)
    agent_model_opts = agent_model_opt(agent, explicit_model)
    result = model_opts ++ agent_opts ++ agent_model_opts
    result ++ env_model(result)
  end

  def detect_and_merge_agent(name, opts) do
    merged = opts ++ agent_opt(El.AgentDetector.detect_agent(name))
    merged ++ env_model(merged)
  end

  defp agent_opt(nil), do: []
  defp agent_opt(agent), do: [agent: agent]

  defp agent_model_opt(nil, _), do: []
  defp agent_model_opt(_, explicit_model) when explicit_model != nil, do: []
  defp agent_model_opt(agent, nil) do
    agent_metadata = Application.get_env(:el, :agent_metadata, El.AgentMetadata)
    agent_model_for(agent_metadata.model_for(agent))
  end

  defp agent_model_for(nil), do: []
  defp agent_model_for(model), do: [model: model]

  defp env_model(opts) do
    env_model_for(Keyword.get(opts, :model), Keyword.get(opts, :agent))
  end

  defp env_model_for(nil, nil) do
    subagent_model(System.get_env("CLAUDE_CODE_SUBAGENT_MODEL"))
  end

  defp env_model_for(_, _), do: []

  defp subagent_model(nil), do: []
  defp subagent_model(model), do: [model: model]

  def handle_find_daemon_for_start(name, opts, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    IO.puts("el: #{name} is up")
  end

  def handle_find_daemon_with_rest(name, opts, rest, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    dispatch_rest(rest, name)
  end

  def dispatch_rest([], _name) do
    :ok
  end

  def dispatch_rest(rest, name) do
    El.CLI.dispatch([name | rest])
  end

  def start_daemon_node_for(name, model, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, start_opts(normalize_model(model)))
    report_daemon_up(name)
    hold_forever()
  end

  defp report_daemon_up(name) do
    IO.puts("el: #{name} is up on #{Node.self()}")
  end

  defp hold_forever do
    Process.sleep(:infinity)
  end
end
