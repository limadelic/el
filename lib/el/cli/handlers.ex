defmodule El.CLI.Handlers do
  alias El.CLI.{Output, Log, Pattern, Messaging, Start}

  def handle_usage, do: IO.puts(Output.usage_message())
  def handle_version(version), do: IO.puts(version)
  def handle_ls(el), do: el.ls() |> Output.show_sessions()

  def handle_daemon_hub, do: Process.sleep(:infinity)

  def handle_daemon_start(["--daemon", name], _context, el) do
    Start.start_daemon_node_for(name, "", el)
  end

  def handle_daemon_start(["--daemon", name, "-m", model], _context, el) do
    Start.start_daemon_node_for(name, model, el)
  end

  def handle_start([name], _context, el) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(nil))
    Start.handle_find_daemon_for_start(name, opts, el)
  end

  def handle_start([name, "-m", model | rest], _context, el) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(model))
    Start.handle_find_daemon_with_rest(name, opts, rest, el)
  end

  def handle_start([name, "-a", agent | rest], _context, el) do
    opts = Start.agent_opts(agent)
    Start.handle_find_daemon_with_rest(name, opts, rest, el)
  end

  def handle_tell_ask([name, "tell", "ask", "@" <> target | words], _context, el) do
    Messaging.execute_tell_ask(name, target, words, el)
  end

  def handle_ask_tell([name, "ask", "tell", "@" <> target | words], _context, el) do
    Messaging.execute_ask_tell(name, target, words, el)
  end

  def handle_msg([name, word | more_words], _context, el) do
    opts = Start.detect_and_merge_agent(name, Start.start_opts(nil))
    el.start(String.to_atom(name), opts)
    Messaging.execute_msg(name, [word | more_words], el)
  end

  def handle_log([name, "log"], _context, el) do
    Log.execute_log(name, 1, el)
  end

  def handle_log_n([name, "log", n], _context, el) do
    Log.execute_log(name, Log.parse_log_count(n), el)
  end

  def handle_exit([name, "exit"], _context, el) do
    Pattern.exit_by_kind(el, Pattern.pattern?(name), name)
  end

  def handle_clear([name, "clear"], _context, el) do
    Pattern.clear_by_kind(el, Pattern.pattern?(name), name)
  end

  def handle_exit_all(["exit"], _context, el) do
    el.exit(:all)
    IO.puts("exited all")
  end
end
