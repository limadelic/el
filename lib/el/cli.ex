defmodule El.CLI do
  alias El.CLI.{Daemon, Router, Output, Log}

  defp version(vsn) when is_list(vsn), do: "v" <> List.to_string(vsn)
  defp version(_), do: "v0.1.0"

  defp version do
    Application.spec(:el, :vsn) |> version()
  end

  defp el, do: Application.get_env(:el, :el_module, El)

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
    :rpc.call(node, El.CLI, :dispatch, [args])
  end

  defp run_dispatch(:local, args) do
    dispatch(args)
  end

  def dispatch(args) do
    args |> Router.parse_route() |> execute(args)
  end

  def execute(:usage, _args) do
    IO.puts(Output.usage_message())
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
    Log.execute_log(name, 1, el())
  end

  def execute(:log_n, [name, "log", n]) do
    Log.execute_log(name, Log.parse_log_count(n), el())
  end

  def execute(:exit, [name, "exit"]) do
    exit_by_kind(pattern?(name), name)
  end

  defp exit_by_kind(true, name), do: exit_pattern(name)
  defp exit_by_kind(false, name), do: exit_single(name)

  defp exit_pattern(name) do
    el().exit_pattern(name)
    IO.puts("exited sessions matching #{name}")
  end

  defp exit_single(name) do
    handle_exit(String.to_atom(name), name)
  end

  def execute(:clear, [name, "clear"]) do
    clear_by_kind(pattern?(name), name)
  end

  defp clear_by_kind(true, name), do: clear_pattern(name)
  defp clear_by_kind(false, name), do: clear_single(name)

  defp clear_pattern(name) do
    el().clear_pattern(name)
    IO.puts("cleared sessions matching #{name}")
  end

  defp clear_single(name) do
    result = el().clear(String.to_atom(name))
    Output.handle_result(result, name)
  end

  defp pattern?(name) do
    String.contains?(name, ["*", "?"])
  end

  def execute(:exit_all, ["exit"]) do
    el().exit(:all)
    IO.puts("exited all")
  end

  defp start_opts(nil), do: []
  defp start_opts(model), do: [model: model]

  defp normalize_model("") do
    nil
  end

  defp normalize_model(model) do
    model
  end

  defp handle_ls do
    el().ls() |> Output.show_sessions()
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
    Output.handle_result(result, name)
  end

  defp handle_ask_tell(name_atom, target_atom, msg, name) do
    result = el().ask_tell(name_atom, target_atom, msg)
    Output.handle_result(result, name)
  end

  defp handle_msg(name_atom, msg, name) do
    result = el().ask(name_atom, msg)
    Output.handle_result(result, name)
  end

  defp handle_exit(name_atom, name) do
    result = el().exit(name_atom)
    Output.handle_result(result, name)
  end
end
