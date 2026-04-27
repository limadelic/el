defmodule El do
  defp registry, do: Application.get_env(:el, :registry, Registry)
  defp supervisor, do: Application.get_env(:el, :supervisor, DynamicSupervisor)
  defp session, do: Application.get_env(:el, :session, El.Session)
  defp app, do: Application.get_env(:el, :app, El.Application)
  defp monitor, do: Application.get_env(:el, :monitor, El.ProcessMonitor)

  def start(name, opts \\ []) when is_atom(name) do
    start_if_needed(name, opts, registry().lookup(El.Registry, name))
  end

  defp start_if_needed(name, _opts, [{_pid, _}]) do
    name
  end

  defp start_if_needed(name, opts, []) do
    filtered_opts =
      Keyword.drop(opts, [:registry, :supervisor, :monitor, :app])

    supervisor().start_child(
      El.SessionSupervisor,
      {El.Session, {name, filtered_opts}}
    )

    name
  end

  def tell(name, message) do
    session().tell(name, message)
  end

  def ask(name, message) do
    session().ask(name, message)
  end

  def log(name) do
    session().log(name)
  end

  def log(name, count) do
    session().log(name, count)
  end

  def clear(name) do
    session().clear(name)
  end

  def tell_ask(name, target, message) do
    session().tell_ask(name, target, message)
  end

  def ask_tell(name, target, message) do
    session().ask_tell(name, target, message)
  end

  def exit(name) do
    case name do
      :all -> ls() |> Enum.each(&El.exit/1)
      _ -> do_exit(name)
    end
  end

  def exit_pattern(pattern) do
    ls()
    |> Enum.filter(&match_pattern?(&1, pattern))
    |> Enum.each(&El.exit/1)
  end

  def clear_pattern(pattern) do
    ls() |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&El.clear/1)
  end

  def log_pattern(pattern, count) do
    ls()
    |> Enum.filter(&match_pattern?(&1, pattern))
    |> Enum.flat_map(fn name ->
      case session().log(name, count) do
        :not_found -> []
        entries -> entries
      end
    end)
  end

  defp match_pattern?(name, pattern) do
    name_str = Atom.to_string(name)
    regex_pattern = pattern_to_regex(pattern)
    Regex.match?(~r/^#{regex_pattern}$/, name_str)
  end

  defp pattern_to_regex(pattern) do
    pattern
    |> String.replace("*", ".*")
    |> String.replace("?", ".")
  end

  defp do_exit(name) do
    exit_if_found(name, registry().lookup(El.Registry, name))
  rescue
    _ -> :ok
  end

  defp exit_if_found(name, [{pid, _}]) do
    ref = Process.monitor(pid)
    supervisor().terminate_child(El.SessionSupervisor, pid)
    monitor().wait_for_down(ref, name)
  end

  defp exit_if_found(name, []) do
    app().delete_session_messages(name)
    :not_found
  end

  def ls do
    registry().select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end
end
