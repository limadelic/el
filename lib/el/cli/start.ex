defmodule El.CLI.Start do
  alias El.CLI.Start.CardBox
  alias El.CLI.Start.DaemonHealth
  alias El.CLI.Start.Options
  alias El.CLI.Start.SessionCard

  def merge_session_opts(name, explicit_agent \\ nil, explicit_model \\ nil, deps \\ []) do
    agent = resolve_agent(explicit_agent, name, deps)
    base = build_base_opts(explicit_model, agent, deps)
    base ++ env_model(base)
  end

  defp build_base_opts(explicit_model, agent, deps) do
    Options.start_opts(explicit_model) ++
      Options.agent_opt(agent) ++
      agent_model_opt(agent, explicit_model, deps)
  end

  defp resolve_agent(nil, name, deps), do: Options.agent_detector(deps).detect_agent(name)
  defp resolve_agent(agent, _name, _deps), do: agent

  def detect_and_merge_agent(name, opts, deps \\ []) do
    merged = opts ++ Options.agent_opt(Options.agent_detector(deps).detect_agent(name))
    merged ++ env_model(merged)
  end

  defp agent_model_opt(nil, _, _), do: []
  defp agent_model_opt(_, explicit_model, _) when explicit_model != nil, do: []
  defp agent_model_opt(agent, nil, deps) do
    metadata = Options.agent_metadata(deps)
    Options.agent_model_for(metadata.model_for(agent))
  end

  defp env_model(opts) do
    env_model_for(Keyword.get(opts, :model), Keyword.get(opts, :agent))
  end

  defp env_model_for(nil, nil) do
    Options.subagent_model(System.get_env("CLAUDE_CODE_SUBAGENT_MODEL"))
  end

  defp env_model_for(_, _), do: []

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
    el.start(name_atom, Options.start_opts(Options.normalize_model(model)) ++ deps)
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
