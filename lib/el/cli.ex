defmodule El.CLI do
  alias El.CLI.{Daemon, Router, Output, Log, Pattern, Messaging, Start}

  defp version do
    Application.spec(:el, :vsn) |> Output.format_version()
  end

  defp el, do: Application.get_env(:el, :el_module, El)

  defp client_context do
    %{model: System.get_env("CLAUDE_CODE_SUBAGENT_MODEL")}
  end

  def main(["--daemon" | _] = args) do
    Daemon.start_daemon_node()
    dispatch(args)
  end

  def main(args) do
    connect_and_dispatch(args)
    System.halt(0)
  end

  defp connect_and_dispatch(args) do
    Daemon.connect_to_daemon() |> run_dispatch(args)
  end

  defp run_dispatch({:ok, node}, args) do
    :rpc.call(node, El.CLI, :dispatch, [args, client_context()])
  end

  defp run_dispatch(:local, args) do
    dispatch(args)
  end

  def dispatch(args) do
    dispatch(args, %{})
  end

  def dispatch(args, context) do
    args |> Router.parse_route() |> execute(args, context)
  end

  def execute(route, args) do
    execute(route, args, %{})
  end

  def execute(:usage, _args, _context), do: IO.puts(Output.usage_message())
  def execute(:version, _args, _context), do: IO.puts(version())
  def execute(:ls, _args, _context), do: el().ls() |> Output.show_sessions()
  def execute(:daemon_hub, _args, _context), do: Process.sleep(:infinity)
  def execute(:daemon, ["--daemon", name], _context) do
    execute(:daemon, ["--daemon", name, "-m", ""], %{})
  end
  def execute(:daemon, ["--daemon", name, "-m", model], _context) do
    Start.start_daemon_node_for(name, model, el())
  end
  def execute(:start, [name], _context) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(nil))
    Start.handle_find_daemon_for_start(name, opts, el())
  end
  def execute(:start, [name, "-m", model | rest], _context) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(model))
    Start.handle_find_daemon_with_rest(name, opts, rest, el())
  end
  def execute(:start, [name, "-a", agent | rest], _context) do
    opts = Start.agent_opts(agent)
    Start.handle_find_daemon_with_rest(name, opts, rest, el())
  end
  def execute(:tell_ask, [name, "tell", "ask", "@" <> target | words], _context) do
    Messaging.execute_tell_ask(name, target, words, el())
  end
  def execute(:ask_tell, [name, "ask", "tell", "@" <> target | words], _context) do
    Messaging.execute_ask_tell(name, target, words, el())
  end
  def execute(:msg, [name, word | more_words], _context) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(nil))
    el().start(String.to_atom(name), opts)
    Messaging.execute_msg(name, [word | more_words], el())
  end
  def execute(:log, [name, "log"], _context), do: Log.execute_log(name, 1, el())
  def execute(:log_n, [name, "log", n], _context) do
    Log.execute_log(name, Log.parse_log_count(n), el())
  end
  def execute(:exit, [name, "exit"], _context) do
    Pattern.exit_by_kind(el(), Pattern.pattern?(name), name)
  end
  def execute(:clear, [name, "clear"], _context) do
    Pattern.clear_by_kind(el(), Pattern.pattern?(name), name)
  end
  def execute(:exit_all, ["exit"], _context) do
    el().exit(:all)
    IO.puts("exited all")
  end
end
