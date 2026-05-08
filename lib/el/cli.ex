defmodule El.CLI do
  alias El.CLI.{Router, Output, Log, Pattern, Start, Msg, Json}

  defp version do
    Application.spec(:el, :vsn) |> Output.format_version()
  end

  defp el(opts), do: Keyword.fetch!(opts, :el_module)

  defp daemon(opts), do: Keyword.get(opts, :daemon_module, El.CLI.Daemon)

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

  def execute(:start, [name, "start" | rest], deps), do: execute(:start, [name | rest], deps)

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

  def execute(:log, [name, "log"], opts), do: Log.execute(name, opts)
  def execute(:log_json, [name, "log"], opts), do: Json.execute_log(name, 1, el(opts), opts)
  def execute(:log_n, [name, "log", n], opts), do: Log.execute_n(name, n, opts)
  def execute(:log_n_json, [name, "log", n, "-json"], opts) do
    Json.execute_log_n(name, n, opts)
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

  def execute(:clear_all, ["clear"], opts) do
    el(opts).clear_pattern("*", opts)
    IO.puts("cleared all")
  end

  def execute(:restart_daemon, ["restart"], opts) do
    daemon(opts).restart_daemon(opts)
    IO.puts("daemon restarted")
  end
  def execute(:info, [name], deps) do
    session_api = Keyword.get(deps, :session_api, El.Session.Api)
    print_info(session_api.alive?(String.to_atom(name)), name, session_api, deps)
  end
  def execute(:info_json, [name], deps), do: Json.execute_info(name, deps)
  def execute(:restart, [name, "restart"], opts) do
    Pattern.restart_by_kind(el(opts), Pattern.pattern?(name), name, opts)
  end
  def execute(:restart, [name], deps) do
    name_atom = String.to_atom(name)
    el(deps).restart(name_atom, deps)
    Start.print_session_info(name, [], deps)
  end

  defp print_info(true, name, session_api, deps) do
    name_atom = String.to_atom(name)
    agent = session_api.agent(name_atom)
    info = session_api.info(name_atom)
    model = info[:model]
    opts = []
    opts = opts |> maybe_put(:agent, agent) |> maybe_put(:model, model)
    Start.print_session_info(name, opts, deps)
  end
  defp print_info(false, _name, _session_api, _deps), do: IO.puts(Output.usage_message())

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp maybe_print_card(:created, name, opts, deps), do: Start.print_session_info(name, opts, deps)
  defp maybe_print_card(:already_running, _name, _opts, _deps), do: :ok
end
