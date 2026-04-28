defmodule El do
  def registry, do: Application.get_env(:el, :registry, Registry)
  def supervisor, do: Application.get_env(:el, :supervisor, DynamicSupervisor)
  def session, do: Application.get_env(:el, :session, El.Session)
  def app, do: Application.get_env(:el, :app, El.Application)
  def monitor, do: Application.get_env(:el, :monitor, El.ProcessMonitor)

  def start(name, opts \\ []) when is_atom(name) do
    start_if_needed(name, opts, registry().lookup(El.Registry, name))
  end

  defp start_if_needed(name, _opts, [{_pid, _}]) do
    name
  end

  defp start_if_needed(name, opts, []) do
    filtered_opts = filter_session_opts(opts)
    start_session_child(name, filtered_opts)
    name
  end

  defp start_session_child(name, opts) do
    spec = %{id: name, start: {El.Session.Api, :start_link, [{name, opts}]}, restart: :temporary}
    supervisor().start_child(El.SessionSupervisor, spec)
  end

  defp filter_session_opts(opts) do
    Keyword.drop(opts, [:registry, :supervisor, :monitor, :app])
  end

  def tell(name, message) do
    session_api().tell(name, message)
  end

  def ask(name, message) do
    session_api().ask(name, message)
  end

  def log(name) do
    session_api().log(name)
  end

  def log(name, count) do
    session_api().log(name, count)
  end

  def clear(name) do
    session_api().clear(name)
  end

  def tell_ask(name, target, message), do: session_api().tell_ask(name, target, message)
  def ask_tell(name, target, message), do: session_api().ask_tell(name, target, message)
  defp session_api, do: Application.get_env(:el, :session_api, El.Session.Api)

  def exit(name) do
    El.Lifecycle.exit(name)
  end

  def exit_pattern(pattern) do
    ls()
    |> Enum.filter(&match_pattern?(&1, pattern))
    |> Enum.each(&El.exit/1)
  end

  def clear_pattern(pattern) do
    ls() |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&El.clear/1)
  end

  def log_pattern(pattern, count),
    do:
      ls() |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.flat_map(&log_entries(&1, count))

  defp log_entries(name, count) do
    name |> session_api().log(count) |> filter_found()
  end

  defp filter_found(:not_found), do: []
  defp filter_found(entries), do: entries

  defp match_pattern?(name, pattern) do
    name_str = Atom.to_string(name)
    regex_pattern = pattern_to_regex(pattern)
    Regex.match?(~r/^#{regex_pattern}$/, name_str)
  end

  defp pattern_to_regex(pattern),
    do: pattern |> String.replace("*", ".*") |> String.replace("?", ".")

  def ls do
    registry().select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end
end
