defmodule El.CLI do
  alias El.CLI.{Router, Output, Log, Pattern, Messaging, Start}

  defp version do
    Application.spec(:el, :vsn) |> Output.format_version()
  end

  defp el(opts \\ []), do: Keyword.get(opts, :el_module, Application.get_env(:el, :el_module, El))

  def dispatch(args) do
    args |> Router.parse_route() |> execute(args, [])
  end

  def execute(:usage, _args, _deps), do: IO.puts(Output.usage_message())
  def execute(:version, _args, _deps), do: IO.puts(version())
  def execute(:ls, _args, _deps), do: el().ls() |> Output.show_sessions()
  def execute(:daemon_hub, _args, _deps), do: Process.sleep(:infinity)

  def execute(:daemon, ["--daemon", name], _deps) do
    execute(:daemon, ["--daemon", name, "-m", ""], [])
  end

  def execute(:daemon, ["--daemon", name, "-m", model], _deps) do
    Start.start_daemon_node_for(name, model, el())
  end

  def execute(:start, [name], deps) do
    opts = Start.merge_session_opts(name, nil, nil, deps)
    Start.handle_find_daemon_for_start(name, opts, el(), deps)
  end

  def execute(:start, [name, "-m", model | rest], deps) do
    opts = Start.merge_session_opts(name, nil, model, deps)
    Start.handle_find_daemon_with_rest(name, opts, rest, el(), deps)
  end

  def execute(:start, [name, "-a", agent | rest], deps) do
    opts = Start.merge_session_opts(name, agent, nil, deps)
    Start.handle_find_daemon_with_rest(name, opts, rest, el(), deps)
  end

  def execute(:tell_ask, [name, "tell", "ask", "@" <> target | words], _deps) do
    Messaging.execute_tell_ask(name, target, words, el())
  end

  def execute(:ask_tell, [name, "ask", "tell", "@" <> target | words], _deps) do
    Messaging.execute_ask_tell(name, target, words, el())
  end

  def execute(:msg, [name, word | more_words], deps) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(nil), deps)
    status = el().start(String.to_atom(name), opts)
    Messaging.execute_msg(name, [word | more_words], el())
    maybe_print_card(status, name, opts, deps)
  end

  def execute(:log, [name, "log"], _deps), do: Log.execute_log(name, 1, el())

  def execute(:log_n, [name, "log", n], _deps) do
    Log.execute_log(name, Log.parse_log_count(n), el())
  end

  def execute(:exit, [name, "exit"], _deps) do
    Pattern.exit_by_kind(el(), Pattern.pattern?(name), name)
  end

  def execute(:clear, [name, "clear"], _deps) do
    Pattern.clear_by_kind(el(), Pattern.pattern?(name), name)
  end

  def execute(:exit_all, ["exit"], _deps) do
    el().exit(:all)
    IO.puts("exited all")
  end

  defp maybe_print_card(:created, name, opts, deps), do: Start.print_session_info(name, opts, deps)
  defp maybe_print_card(:already_running, _name, _opts, _deps), do: :ok
end
