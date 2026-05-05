defmodule El.CLI.Start do
  alias El.CLI.Start.CardBox
  alias El.CLI.Start.DaemonHealth
  alias El.CLI.Start.SessionCard

  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def merge_session_opts(name, explicit_agent \\ nil, explicit_model \\ nil, deps \\ []) do
    agent = resolve_agent(explicit_agent, name, deps)
    base = build_base_opts(explicit_model, agent, deps)
    base ++ env_model(base)
  end

  defp build_base_opts(explicit_model, agent, deps) do
    start_opts(explicit_model) ++
      agent_opt(agent) ++
      agent_model_opt(agent, explicit_model, deps)
  end

  defp resolve_agent(nil, name, deps), do: agent_detector(deps).detect_agent(name)
  defp resolve_agent(agent, _name, _deps), do: agent

  def detect_and_merge_agent(name, opts, deps \\ []) do
    merged = opts ++ agent_opt(agent_detector(deps).detect_agent(name))
    merged ++ env_model(merged)
  end

  defp agent_detector(deps) do
    Keyword.get(deps, :agent_detector, El.AgentDetector)
  end

  defp agent_opt(nil), do: []
  defp agent_opt(agent), do: [agent: agent]

  defp agent_model_opt(nil, _, _), do: []
  defp agent_model_opt(_, explicit_model, _) when explicit_model != nil, do: []
  defp agent_model_opt(agent, nil, deps) do
    metadata = agent_metadata(deps)
    agent_model_for(metadata.model_for(agent))
  end

  defp agent_metadata(deps) do
    Keyword.get(deps, :agent_metadata, El.AgentMetadata)
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

  def handle_find_daemon_for_start(name, opts, el, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts ++ deps)
    DaemonHealth.ping_if_agent(name_atom, opts, deps)
    print_session_info(name, opts, deps)
  end

  def print_session_info(name, opts, deps \\ []) do
    info = session_api(deps).info(String.to_atom(name))
    rows = SessionCard.build_card_rows(name, opts, info)
    CardBox.box_frame(rows) |> Enum.each(&IO.puts/1)
  end

  defp session_api(deps) do
    Keyword.get(deps, :session_api, El.Session.Api)
  end

  def handle_find_daemon_with_rest(name, opts, rest, el, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts ++ deps)
    print_session_info(name, opts, deps)
    dispatch_rest(rest, name, opts)
  end

  def dispatch_rest([], _name, _opts) do
    :ok
  end

  def dispatch_rest(rest, name, opts) do
    El.CLI.dispatch([name | rest], opts)
  end

  def start_daemon_node_for(name, model, el, sleeper \\ El.SleeperImpl, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, start_opts(normalize_model(model)) ++ deps)
    report_daemon_up(name)
    hold_forever(sleeper)
  end

  defp report_daemon_up(name) do
    IO.puts("el: #{name} is up on #{Node.self()}")
  end

  defp hold_forever(sleeper) do
    sleeper.sleep(:infinity)
  end
end
