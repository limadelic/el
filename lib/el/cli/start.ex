defmodule El.CLI.Start do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def merge_session_opts(name, explicit_agent \\ nil, explicit_model \\ nil) do
    model_opts = start_opts(explicit_model)
    agent = explicit_agent || agent_detector().detect_agent(name)
    agent_opts = agent_opt(agent)
    agent_model_opts = agent_model_opt(agent, explicit_model)
    result = model_opts ++ agent_opts ++ agent_model_opts
    result ++ env_model(result)
  end

  def detect_and_merge_agent(name, opts) do
    merged = opts ++ agent_opt(agent_detector().detect_agent(name))
    merged ++ env_model(merged)
  end

  defp agent_detector do
    Application.get_env(:el, :agent_detector, El.AgentDetector)
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
    ping_if_agent(name_atom, opts)
    print_session_info(name, opts)
  end

  defp ping_if_agent(name_atom, opts), do: do_ping(name_atom, Keyword.get(opts, :agent))

  defp do_ping(_name_atom, nil), do: :ok
  defp do_ping(name_atom, _agent), do: session_api().ask(name_atom, "who are you?")

  defp print_session_info(name, opts) do
    print_agent_if_present(Keyword.get(opts, :agent))
    print_model_if_present(Keyword.get(opts, :model))
    print_name(name)
    print_msgs(name)
  end

  defp print_agent_if_present(nil), do: :ok
  defp print_agent_if_present(agent), do: IO.puts("agent #{agent}")

  defp print_model_if_present(nil), do: :ok
  defp print_model_if_present(model), do: IO.puts("model #{model}")

  defp print_name(name), do: IO.puts("name #{name}")

  defp print_msgs(name) do
    info = session_api().info(String.to_atom(name))
    IO.puts("msgs #{info.messages}")
  end

  defp session_api do
    Application.get_env(:el, :session_api, El.Session.Api)
  end

  def handle_find_daemon_with_rest(name, opts, rest, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    print_session_info(name, opts)
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
