defmodule El.CLI.Start do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def agent_opts(nil), do: []
  def agent_opts(agent), do: [agent: agent]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def detect_and_merge_agent(name, opts, context) do
    merged = opts ++ agent_opt(El.AgentDetector.detect_agent(name))
    merged ++ env_model(merged, context)
  end

  defp agent_opt(nil), do: []
  defp agent_opt(agent), do: [agent: agent]

  defp env_model(opts, context) do
    env_model_for(Keyword.get(opts, :model), Keyword.get(opts, :agent), context)
  end

  defp env_model_for(nil, nil, context) do
    subagent_model(Map.get(context, :model))
  end

  defp env_model_for(_, _, _), do: []

  defp subagent_model(nil), do: []
  defp subagent_model(model), do: [model: model]

  def handle_find_daemon_for_start(name, opts, el) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    IO.puts("el: #{name} is up")
  end

  def handle_find_daemon_with_rest(name, opts, rest, el) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
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
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
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
