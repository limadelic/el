defmodule El.CLI do
  alias El.CLI.{Router, Output, Log, Pattern, Start, Msg}

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
    Start.start_daemon_node_for(name, model, el(opts), El.Infra.Sleeper, opts)
  end

  def execute(:start, [name], deps) do
    opts = Start.Options.merge_session_opts(name, nil, nil, deps)
    Start.handle_find_daemon_for_start(name, opts, el(deps), deps)
  end

  def execute(:start, [name, "-m", model | rest], deps) do
    opts = Start.Options.merge_session_opts(name, nil, model, deps)
    Start.handle_find_daemon_with_rest(name, opts, rest, el(deps), deps)
  end

  def execute(:start, [name, "-a", agent | rest], deps) do
    opts = Start.Options.merge_session_opts(name, agent, nil, deps)
    Start.handle_find_daemon_with_rest(name, opts, rest, el(deps), deps)
  end

  def execute(:msg, [name, word | more_words], deps) do
    opts = Start.Options.merge_session_opts(name, nil, nil, deps)
    status = el(deps).start(String.to_atom(name), opts ++ deps)
    Msg.dispatch(name, [word | more_words], el(deps), deps)
    maybe_print_card(status, name, opts, deps)
  end

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

  def execute(:info, [name], deps) do
    session_api = Keyword.get(deps, :session_api, El.Session.Api)
    print_info(session_api.alive?(String.to_atom(name)), name, deps)
  end

  def execute(:restart, [name, "restart"], opts) do
    Pattern.restart_by_kind(el(opts), Pattern.pattern?(name), name, opts)
  end

  def execute(:restart, [name], deps) do
    el(deps).restart(String.to_atom(name), deps)
    Start.print_session_info(name, [], deps)
  end

  defp print_info(true, name, deps), do: Start.print_session_info(name, [], deps)
  defp print_info(false, _name, _deps), do: IO.puts(Output.usage_message())

  defp maybe_print_card(:created, name, opts, deps), do: Start.print_session_info(name, opts, deps)
  defp maybe_print_card(:already_running, _name, _opts, _deps), do: :ok
end
