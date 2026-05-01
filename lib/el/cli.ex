defmodule El.CLI do
  alias El.CLI.{Router, Output, Log, Pattern, Messaging, Start}

  defp version do
    Application.spec(:el, :vsn) |> Output.format_version()
  end

  defp el, do: Application.get_env(:el, :el_module, El)

  def dispatch(args) do
    args |> Router.parse_route() |> execute(args)
  end

  def execute(:usage, _args), do: IO.puts(Output.usage_message())
  def execute(:version, _args), do: IO.puts(version())
  def execute(:ls, _args), do: el().ls() |> Output.show_sessions()
  def execute(:daemon_hub, _args), do: Process.sleep(:infinity)

  def execute(:daemon, ["--daemon", name]) do
    execute(:daemon, ["--daemon", name, "-m", ""])
  end

  def execute(:daemon, ["--daemon", name, "-m", model]) do
    Start.start_daemon_node_for(name, model, el())
  end

  def execute(:start, [name]) do
    opts = Start.merge_session_opts(name)
    Start.handle_find_daemon_for_start(name, opts, el())
  end

  def execute(:start, [name, "-m", model | rest]) do
    opts = Start.merge_session_opts(name, nil, model)
    Start.handle_find_daemon_with_rest(name, opts, rest, el())
  end

  def execute(:start, [name, "-a", agent | rest]) do
    opts = Start.merge_session_opts(name, agent, nil)
    Start.handle_find_daemon_with_rest(name, opts, rest, el())
  end

  def execute(:tell_ask, [name, "tell", "ask", "@" <> target | words]) do
    Messaging.execute_tell_ask(name, target, words, el())
  end

  def execute(:ask_tell, [name, "ask", "tell", "@" <> target | words]) do
    Messaging.execute_ask_tell(name, target, words, el())
  end

  def execute(:msg, [name, word | more_words]) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(nil))
    status = el().start(String.to_atom(name), opts)
    Messaging.execute_msg(name, [word | more_words], el())
    maybe_print_card(status, name, opts)
  end

  def execute(:log, [name, "log"]), do: Log.execute_log(name, 1, el())

  def execute(:log_n, [name, "log", n]) do
    Log.execute_log(name, Log.parse_log_count(n), el())
  end

  def execute(:exit, [name, "exit"]) do
    Pattern.exit_by_kind(el(), Pattern.pattern?(name), name)
  end

  def execute(:clear, [name, "clear"]) do
    Pattern.clear_by_kind(el(), Pattern.pattern?(name), name)
  end

  def execute(:exit_all, ["exit"]) do
    el().exit(:all)
    IO.puts("exited all")
  end

  defp maybe_print_card(:created, name, opts), do: Start.print_session_info(name, opts)
  defp maybe_print_card(:already_running, _name, _opts), do: :ok
end
