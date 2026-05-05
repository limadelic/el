defmodule El.CLI do
  alias El.CLI.{Router, Output, Log, Pattern, Start}

  defp version do
    Application.spec(:el, :vsn) |> Output.format_version()
  end

  defp el(opts), do: Keyword.fetch!(opts, :el_module)

  def dispatch(args), do: dispatch(args, El.Deps.production())

  def dispatch(args, opts) do
    args |> Router.parse_route() |> execute(args, opts)
  end

  def execute(:usage, _args, _opts), do: IO.puts(Output.usage_message())
  def execute(:version, _args, _opts), do: IO.puts(version())
  def execute(:ls, _args, opts), do: el(opts).ls(opts) |> Output.show_sessions()
  def execute(:daemon_hub, _args, _opts), do: Process.sleep(:infinity)

  def execute(:daemon, ["--daemon", name], opts) do
    execute(:daemon, ["--daemon", name, "-m", ""], opts)
  end

  def execute(:daemon, ["--daemon", name, "-m", model], opts) do
    Start.start_daemon_node_for(name, model, el(opts), El.SleeperImpl, opts)
  end

  def execute(:start, [name], deps) do
    opts = Start.merge_session_opts(name, nil, nil, deps)
    Start.handle_find_daemon_for_start(name, opts, el(deps), deps)
  end

  def execute(:start, [name, "-m", model | rest], deps) do
    opts = Start.merge_session_opts(name, nil, model, deps)
    Start.handle_find_daemon_with_rest(name, opts, rest, el(deps), deps)
  end

  def execute(:start, [name, "-a", agent | rest], deps) do
    opts = Start.merge_session_opts(name, agent, nil, deps)
    Start.handle_find_daemon_with_rest(name, opts, rest, el(deps), deps)
  end

  def execute(:msg, [name, word | more_words], deps) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(nil), deps)
    status = el(deps).start(String.to_atom(name), opts ++ deps)
    name_atom = String.to_atom(name)
    message = Enum.join([word | more_words], " ")
    result = el(deps).ask(name_atom, message, deps)
    agent_name = agent_safe(el(deps), name_atom, name, deps)
    Output.handle_result(result, resolve_name(agent_name, name))
    maybe_print_card(status, name, opts, deps)
  end

  defp agent_safe(el_module, name_atom, _fallback, opts) do
    el_module.agent(name_atom, opts)
  catch
    _ -> nil
  end

  defp resolve_name(nil, fallback), do: fallback
  defp resolve_name(agent, _fallback), do: agent

  def execute(:log, [name, "log"], opts), do: Log.execute_log(name, 1, el(opts), opts)

  def execute(:log_n, [name, "log", n], opts) do
    Log.execute_log(name, Log.parse_log_count(n), el(opts), opts)
  end

  def execute(:exit, [name, "exit"], opts) do
    Pattern.exit_by_kind(el(opts), Pattern.pattern?(name), name, opts)
  end

  def execute(:clear, [name, "clear"], opts) do
    Pattern.clear_by_kind(el(opts), Pattern.pattern?(name), name, opts)
  end

  def execute(:exit_all, ["exit"], opts) do
    el(opts).exit(:all, opts)
    IO.puts("exited all")
  end

  defp maybe_print_card(:created, name, opts, deps), do: Start.print_session_info(name, opts, deps)
  defp maybe_print_card(:already_running, _name, _opts, _deps), do: :ok
end
