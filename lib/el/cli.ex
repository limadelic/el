defmodule El.CLI do
  defp version do
    case Application.spec(:el, :vsn) do
      vsn when is_list(vsn) -> "v" <> List.to_string(vsn)
      _ -> "v0.1.0"
    end
  end

  def main(["--daemon" | _] = args) do
    start_daemon_node()
    dispatch(args)
  end

  def main(args) do
    case connect_to_daemon() do
      {:ok, node} -> :rpc.call(node, El.CLI, :dispatch, [args])
      :local -> dispatch(args)
    end
    System.halt(0)
  end

  def dispatch(args) do
    args |> parse_route() |> execute(args)
  end

  def parse_route([]), do: :usage
  def parse_route(["-v"]), do: :version
  def parse_route(["ls"]), do: :ls
  def parse_route(["--daemon"]), do: :daemon_hub
  def parse_route(["--daemon", _name]), do: :daemon
  def parse_route(["--daemon", _name, "-m", _model]), do: :daemon
  def parse_route(["exit", "all"]), do: :exit_all
  def parse_route(["exit", _pattern]), do: :exit_pattern
  def parse_route([_name, "log", _n]), do: :log_n
  def parse_route([_name, "log"]), do: :log
  def parse_route([_name, "exit"]), do: :exit
  def parse_route([_name, "clear"]), do: :clear
  def parse_route([_name, "tell", "ask", "@" <> _target | _words]), do: :tell_ask
  def parse_route([_name, "ask", "tell", "@" <> _target | _words]), do: :ask_tell
  def parse_route([<<c, _::binary>>]) when c != ?-, do: :start
  def parse_route([<<c, _::binary>>, "-m", _model | _rest]) when c != ?-, do: :start
  def parse_route([<<c, _::binary>>, _word | _more_words]) when c != ?-, do: :msg
  def parse_route(_), do: :usage

  def execute(:usage, _args) do
    IO.puts(usage_message())
  end

  def execute(:version, _args) do
    IO.puts(version())
  end

  def execute(:ls, _args) do
    handle_ls()
  end

  def execute(:daemon_hub, _args) do
    Process.sleep(:infinity)
  end

  def execute(:daemon, ["--daemon", name]) do
    execute(:daemon, ["--daemon", name, "-m", ""])
  end

  def execute(:daemon, ["--daemon", name, "-m", model]) do
    name_atom = String.to_atom(name)
    model_value = normalize_model(model)
    opts = start_opts(model_value)

    El.start(name_atom, opts)
    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end

  def execute(:start, [name]) do
    opts = start_opts(nil)

    handle_find_daemon_for_start(name, opts)
  end

  def execute(:start, [name, "-m", model | rest]) do
    opts = start_opts(model)
    handle_find_daemon_with_rest(name, opts, rest)
  end

  def execute(:tell_ask, [name, "tell", "ask", "@" <> target | words]) do
    target_atom = String.to_atom(target)
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_tell_ask(name_atom, target_atom, msg, name)
  end

  def execute(:ask_tell, [name, "ask", "tell", "@" <> target | words]) do
    target_atom = String.to_atom(target)
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_ask_tell(name_atom, target_atom, msg, name)
  end

  def execute(:msg, [name, word | more_words]) do
    msg = Enum.join([word | more_words], " ")
    name_atom = String.to_atom(name)
    handle_msg(name_atom, msg, name)
  end

  def execute(:log, [name, "log"]) do
    name_atom = String.to_atom(name)
    result = El.log(name_atom, 1)
    handle_log_result(result, name)
  end

  def execute(:log_n, [name, "log", n]) do
    name_atom = String.to_atom(name)
    count = parse_log_count(n)
    result = El.log(name_atom, count)
    handle_log_result(result, name)
  end

  def execute(:exit, [name, "exit"]) do
    name_atom = String.to_atom(name)
    handle_exit(name_atom, name)
  end

  def execute(:clear, [name, "clear"]) do
    name_atom = String.to_atom(name)
    result = El.clear(name_atom)
    handle_result(result, name)
  end

  def execute(:exit_all, ["exit", "all"]) do
    El.exit(:all)
    IO.puts("exited all")
  end

  def execute(:exit_pattern, ["exit", pattern]) do
    El.exit_pattern(pattern)
    IO.puts("exited sessions matching #{pattern}")
  end

  defp parse_log_count("all"), do: :all
  defp parse_log_count(n), do: String.to_integer(n)

  defp start_opts(nil), do: []
  defp start_opts(model), do: [model: model]

  defp normalize_model("") do
    nil
  end

  defp normalize_model(model) do
    model
  end

  defp handle_ls do
    case El.ls() do
      [] -> IO.puts(:stderr, "No sessions running. Start one: el <name>")
      names -> Enum.each(names, &IO.puts/1)
    end
  end

  defp handle_find_daemon_for_start(name, opts) do
    name_atom = String.to_atom(name)
    El.start(name_atom, opts)
    IO.puts("el: #{name} is up")
  end

  defp handle_find_daemon_with_rest(name, opts, rest) do
    name_atom = String.to_atom(name)
    El.start(name_atom, opts)
    dispatch_rest(rest, name)
  end

  defp dispatch_rest([], _name) do
    :ok
  end

  defp dispatch_rest(rest, name) do
    dispatch([name | rest])
  end

  defp handle_tell_ask(name_atom, target_atom, msg, name) do
    result = El.tell_ask(name_atom, target_atom, msg)
    handle_result(result, name)
  end

  defp handle_ask_tell(name_atom, target_atom, msg, name) do
    result = El.ask_tell(name_atom, target_atom, msg)
    handle_result(result, name)
  end

  defp handle_msg(name_atom, msg, name) do
    result = El.ask(name_atom, msg)
    handle_result(result, name)
  end

  defp handle_exit(name_atom, name) do
    result = El.exit(name_atom)
    handle_result(result, name)
  end

  defp handle_log_result(:not_found, name) do
    handle_not_found(name)
  end

  defp handle_log_result(log, _name) do
    Enum.each(log, fn {type, message, response, _metadata} ->
      IO.puts("[#{type}] #{message}")
      IO.puts(response)
    end)
  end

  defp handle_result(:not_found, name) do
    handle_not_found(name)
  end

  defp handle_result(response, _name) do
    IO.puts(response)
  end

  defp handle_not_found(name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
  end

  defp usage_message do
    cmds = [
      {"el #{version()}", ""},
      {"el -v", "version"},
      {"el ls", "list sessions"},
      {"el <name> [-m <model>]", "start or status"},
      {"el <name> <msg>", "send a msg"},
      {"el <name> log [N|all]", "view log (default: last 1)"},
      {"el <name> clear", "clear log"},
      {"el <name> exit", "exit session"},
      {"el exit all", "exit all sessions"}
    ]

    pad = cmds |> Enum.map(fn {cmd, _} -> String.length(cmd) end) |> Enum.max()

    cmds
    |> Enum.map_join("\n", fn {cmd, desc} ->
      format_line(cmd, desc, pad)
    end)
  end

  defp format_line(cmd, "", _pad), do: cmd

  defp format_line(cmd, desc, pad) do
    String.pad_trailing(cmd, pad) <> "  " <> desc
  end

  defp daemon_node, do: :"el@127.0.0.1"

  defp start_daemon_node do
    :net_kernel.start([daemon_node(), :longnames])
    Node.set_cookie(:el)
  end

  defp connect_to_daemon do
    with {:ok, _} <- start_client_node(),
         :ok <- ensure_daemon() do
      {:ok, daemon_node()}
    else
      _ -> :local
    end
  end

  defp start_client_node do
    id = System.unique_integer([:positive])
    :net_kernel.start([:"el-cli-#{id}@127.0.0.1", :longnames])
    |> case do
      {:ok, _} -> Node.set_cookie(:el); {:ok, :started}
      error -> error
    end
  end

  defp ensure_daemon do
    if Node.connect(daemon_node()) do
      :ok
    else
      spawn_daemon()
      wait_for_daemon(30)
    end
  end

  defp spawn_daemon do
    script = :escript.script_name() |> to_string()
    System.cmd("sh", ["-c", "#{script} --daemon &"])
  end

  defp wait_for_daemon(0), do: {:error, :timeout}

  defp wait_for_daemon(n) do
    :timer.sleep(100)
    if Node.connect(daemon_node()), do: :ok, else: wait_for_daemon(n - 1)
  end
end
