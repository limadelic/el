defmodule El.CLI do
  defp version do
    case Application.spec(:el, :vsn) do
      vsn when is_list(vsn) -> List.to_string(vsn)
      _ -> "dev"
    end
  end

  def main(args) do
    main_impl(args)
    System.halt(0)
  end

  def dispatch(args) do
    main_impl(args)
  end

  def parse_route([]), do: :usage
  def parse_route(["-v"]), do: :version
  def parse_route(["--version"]), do: :version
  def parse_route(["ls"]), do: :ls
  def parse_route(["--daemon", _name]), do: :daemon
  def parse_route(["--daemon", _name, "--model", _model]), do: :daemon
  def parse_route(["kill", "all"]), do: :kill_all
  def parse_route([_name, "log"]), do: :log
  def parse_route([_name, "kill"]), do: :kill
  def parse_route([_name, "tell", "ask", "@" <> _target | _words]), do: :tell_ask
  def parse_route([_name, "tell" | _words]), do: :tell
  def parse_route([_name, "ask", "tell", "@" <> _target | _words]), do: :ask_tell
  def parse_route([_name, "ask" | _words]), do: :ask
  def parse_route([_name]), do: :start
  def parse_route([_name, "--model", _model | _rest]), do: :start
  def parse_route(_), do: :usage

  defp main_impl([]) do
    IO.puts(usage_message())
  end

  defp main_impl(["-v"]) do
    IO.puts(version())
  end

  defp main_impl(["--version"]) do
    IO.puts(version())
  end

  defp main_impl(["ls"]) do
    handle_ls()
  end

  defp main_impl(["--daemon", name]) do
    main_impl(["--daemon", name, "--model", ""])
  end

  defp main_impl(["--daemon", name, "--model", model]) do
    name_atom = String.to_atom(name)
    model_value = normalize_model(model)
    opts = start_opts(model_value)

    El.start(name_atom, opts)
    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end

  defp main_impl([name]) do
    {model, []} = extract_model_flag([])
    opts = start_opts(model)

    handle_find_daemon_for_start(name, opts)
  end

  defp main_impl([name, "--model", model | rest]) do
    opts = start_opts(model)
    handle_find_daemon_with_rest(name, opts, rest)
  end

  defp main_impl([name, "tell", "ask", "@" <> target | words]) do
    target_atom = String.to_atom(target)
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_tell_ask(name_atom, target_atom, msg, name)
  end

  defp main_impl([name, "tell" | words]) do
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_tell(name_atom, msg, name)
  end

  defp main_impl([name, "ask", "tell", "@" <> target | words]) do
    target_atom = String.to_atom(target)
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_ask_tell(name_atom, target_atom, msg, name)
  end

  defp main_impl([name, "ask" | words]) do
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_ask(name_atom, msg, name)
  end

  defp main_impl([name, "log"]) do
    name_atom = String.to_atom(name)
    handle_log(name_atom, name)
  end

  defp main_impl([name, "kill"]) do
    name_atom = String.to_atom(name)
    handle_kill(name_atom, name)
  end

  defp main_impl(["kill", "all"]) do
    case El.kill(:all) do
      :ok -> IO.puts("killed all")
      _ -> IO.puts("killed all")
    end
  rescue
    _ -> IO.puts("killed all")
  end

  defp main_impl(_) do
    main_impl([])
  end

  defp extract_model_flag(args), do: {nil, args}

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
    continue_if_rest_present(rest, name)
  end

  defp continue_if_rest_present([], _name) do
    :ok
  end

  defp continue_if_rest_present(rest, name) do
    main_impl([name | rest])
  end

  defp handle_tell_ask(name_atom, target_atom, msg, name) do
    case El.tell_ask(name_atom, target_atom, msg) do
      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")

      _ ->
        :ok
    end
  end

  defp handle_tell(name_atom, msg, name) do
    case El.tell(name_atom, msg) do
      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")

      _ ->
        :ok
    end
  end

  defp handle_ask_tell(name_atom, target_atom, msg, name) do
    result = El.ask_tell(name_atom, target_atom, msg)
    handle_result(result, name)
  end

  defp handle_ask(name_atom, msg, name) do
    result = El.ask(name_atom, msg)
    handle_result(result, name)
  end

  defp handle_log(name_atom, name) do
    case El.log(name_atom) do
      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")

      log ->
        Enum.each(log, fn {type, message, response, _metadata} ->
          IO.puts("[#{type}] #{message}")
          IO.puts(response)
        end)
    end
  end

  defp handle_kill(name_atom, name) do
    case El.kill(name_atom) do
      :not_found ->
        IO.puts(:stderr, "No sessions running. Start one: el #{name}")

      _ ->
        :ok
    end
  end

  defp handle_result(:not_found, name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
  end

  defp handle_result(response, _name) do
    IO.puts(response)
  end

  defp usage_message do
    "el #{version()}\nusage: el ls | el <name> [--model <model>] | el <name> [--model <model>] tell <message> | el <name> [--model <model>] ask <message> | el <name> log | el <name> kill | el kill all | el --version"
  end
end
