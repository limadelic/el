defmodule El.CLI do
  defp version(vsn) when is_list(vsn), do: "v" <> List.to_string(vsn)
  defp version(_), do: "v0.1.0"

  defp version do
    Application.spec(:el, :vsn) |> version()
  end

  defp usage_cmds do
    [
      {"el #{version()}", ""},
      {"el -v", "version"},
      {"el ls", "list sessions"},
      {"el <name> [-m <model>]", "start or status"},
      {"el <name> <msg>", "send a msg"},
      {"el <name|glob> log [n|all]", "view log (default: last 1)"},
      {"el <name|glob> clear", "clear log"},
      {"el <name|glob> exit", "exit session"},
      {"el exit", "exit all sessions"}
    ]
  end

  defp el, do: Application.get_env(:el, :el_module, El)

  def dev? do
    System.get_env("DEV") != nil or
      Path.type(to_string(:escript.script_name())) == :relative
  end

  def daemon_script do
    :escript.script_name() |> to_string() |> Path.expand()
  end

  def main(["--daemon" | _] = args) do
    start_daemon_node()
    dispatch(args)
  end

  def main(args) do
    connect_and_dispatch(args)
    System.halt(0)
  end

  defp connect_and_dispatch(args) do
    connect_to_daemon() |> run_dispatch(args)
  end

  defp run_dispatch({:ok, node}, args) do
    :rpc.call(node, El.CLI, :dispatch, [args])
  end

  defp run_dispatch(:local, args) do
    dispatch(args)
  end

  def dispatch(args) do
    args |> parse_route() |> execute(args)
  end

  def parse_route([]), do: :usage
  def parse_route(["-v"]), do: :version
  def parse_route(["ls"]), do: :ls
  def parse_route(["exit"]), do: :exit_all
  def parse_route(["--daemon"]), do: :daemon_hub
  def parse_route(["--daemon", _name]), do: :daemon
  def parse_route(["--daemon", _name, "-m", _model]), do: :daemon
  def parse_route([_name, "log", _n]), do: :log_n
  def parse_route([_name, "log"]), do: :log
  def parse_route([_name, "exit"]), do: :exit
  def parse_route([_name, "clear"]), do: :clear

  def parse_route([_name, "tell", "ask", "@" <> _target | _words]) do
    :tell_ask
  end

  def parse_route([_name, "ask", "tell", "@" <> _target | _words]) do
    :ask_tell
  end

  def parse_route([<<c, _::binary>>]) when c != ?- do
    :start
  end

  def parse_route([<<c, _::binary>>, "-m", _model | _rest]) when c != ?- do
    :start
  end

  def parse_route([<<c, _::binary>>, _word | _more_words]) when c != ?- do
    :msg
  end

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
    start_daemon_node_for(name, model)
  end

  defp start_daemon_node_for(name, model) do
    name_atom = String.to_atom(name)
    opts = start_opts(normalize_model(model))
    el().start(name_atom, opts)
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
    execute_log(name, 1)
  end

  def execute(:log_n, [name, "log", n]) do
    execute_log(name, parse_log_count(n))
  end

  defp execute_log(name, count) when is_binary(name) do
    result = log_for_name(name, count)
    handle_log_result(result, name)
  end

  defp log_for_name(name, count) when is_binary(name) do
    (pattern?(name) && el().log_pattern(name, count)) ||
      el().log(String.to_atom(name), count)
  end

  def execute(:exit, [name, "exit"]) do
    (pattern?(name) && exit_pattern(name)) || exit_single(name)
  end

  defp exit_pattern(name) do
    el().exit_pattern(name)
    IO.puts("exited sessions matching #{name}")
  end

  defp exit_single(name) do
    handle_exit(String.to_atom(name), name)
  end

  def execute(:clear, [name, "clear"]) do
    (pattern?(name) && clear_pattern(name)) || clear_single(name)
  end

  defp clear_pattern(name) do
    el().clear_pattern(name)
    IO.puts("cleared sessions matching #{name}")
  end

  defp clear_single(name) do
    result = el().clear(String.to_atom(name))
    handle_result(result, name)
  end

  defp pattern?(name) do
    String.contains?(name, ["*", "?"])
  end

  def execute(:exit_all, ["exit"]) do
    el().exit(:all)
    IO.puts("exited all")
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
    el().ls() |> show_sessions()
  end

  defp show_sessions([]) do
    IO.puts("No sessions running. Start one: el <name>")
  end

  defp show_sessions(names) do
    Enum.each(names, &IO.puts/1)
  end

  defp handle_find_daemon_for_start(name, opts) do
    name_atom = String.to_atom(name)
    el().start(name_atom, opts)
    IO.puts("el: #{name} is up")
  end

  defp handle_find_daemon_with_rest(name, opts, rest) do
    name_atom = String.to_atom(name)
    el().start(name_atom, opts)
    dispatch_rest(rest, name)
  end

  defp dispatch_rest([], _name) do
    :ok
  end

  defp dispatch_rest(rest, name) do
    dispatch([name | rest])
  end

  defp handle_tell_ask(name_atom, target_atom, msg, name) do
    result = el().tell_ask(name_atom, target_atom, msg)
    handle_result(result, name)
  end

  defp handle_ask_tell(name_atom, target_atom, msg, name) do
    result = el().ask_tell(name_atom, target_atom, msg)
    handle_result(result, name)
  end

  defp handle_msg(name_atom, msg, name) do
    result = el().ask(name_atom, msg)
    handle_result(result, name)
  end

  defp handle_exit(name_atom, name) do
    result = el().exit(name_atom)
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
    IO.puts("No sessions running. Start one: el #{name}")
  end

  defp usage_message do
    cmds = usage_cmds()
    pad = max_cmd_length(cmds)
    Enum.map_join(cmds, "\n", &format_line(&1, pad))
  end

  defp max_cmd_length(cmds) do
    cmds |> Enum.map(fn {cmd, _} -> String.length(cmd) end) |> Enum.max()
  end

  defp format_line({cmd, ""}, _pad), do: cmd

  defp format_line({cmd, desc}, pad) do
    String.pad_trailing(cmd, pad) <> "  " <> desc
  end

  def daemon_node do
    dev?() |> daemon_node_for()
  end

  defp daemon_node_for(true), do: :"el_dev@127.0.0.1"
  defp daemon_node_for(false), do: :"el@127.0.0.1"

  defp start_daemon_node do
    start_epmd()
    :net_kernel.start([daemon_node(), :longnames])
    Node.set_cookie(:el)
  end

  defp connect_to_daemon do
    start_epmd()
    connect_if_ready()
  end

  defp connect_if_ready do
    with {:ok, _} <- start_client_node(), :ok <- ensure_daemon() do
      {:ok, daemon_node()}
    else
      _ -> :local
    end
  end

  defp start_client_node do
    id = System.unique_integer([:positive])
    start_node_with_id(id)
  end

  defp start_node_with_id(id) do
    :net_kernel.start([:"el-cli-#{id}@127.0.0.1", :longnames])
    |> maybe_set_cookie()
  end

  defp maybe_set_cookie({:ok, _}) do
    Node.set_cookie(:el)
    {:ok, :started}
  end

  defp maybe_set_cookie(error), do: error

  defp ensure_daemon do
    Node.connect(daemon_node()) || spawn_and_wait()
  end

  defp spawn_and_wait do
    spawn_daemon()
    wait_for_daemon(30)
  end

  defp start_epmd do
    System.cmd("epmd", ["-daemon"])
  end

  defp spawn_daemon do
    script = daemon_script()
    prefix = dev?() |> env_prefix()
    System.cmd("sh", ["-c", "#{prefix}#{script} --daemon > /dev/null 2>&1 &"])
  end

  defp env_prefix(true), do: "DEV=1 "
  defp env_prefix(false), do: ""

  defp wait_for_daemon(0), do: {:error, :timeout}

  defp wait_for_daemon(n) do
    :timer.sleep(100)
    daemon_node() |> Node.connect() |> check_connected(n)
  end

  defp check_connected(true, _n), do: :ok
  defp check_connected(false, n), do: wait_for_daemon(n - 1)
end
