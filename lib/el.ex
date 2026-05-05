defmodule El do
  def registry(opts \\ []), do: Keyword.get(opts, :registry, Application.get_env(:el, :registry, Registry))
  def supervisor, do: Application.get_env(:el, :supervisor, DynamicSupervisor)
  def session(opts \\ []), do: Keyword.get(opts, :session, Application.get_env(:el, :session, El.Session))
  def app(opts \\ []), do: Keyword.get(opts, :app, Application.get_env(:el, :app, El.Application))
  def monitor(opts \\ []), do: Keyword.get(opts, :monitor, Application.get_env(:el, :monitor, El.ProcessMonitor))

  def start(name, opts \\ []) when is_atom(name) do
    start_if_needed(name, opts, registry().lookup(El.Registry, name))
  end

  defp start_if_needed(_name, _opts, [{_pid, _}]) do
    :already_running
  end

  defp start_if_needed(name, opts, []) do
    filtered_opts = filter_session_opts(opts)
    start_session_child(name, filtered_opts)
    :created
  end

  defp start_session_child(name, opts) do
    supervisor().start_child(El.SessionSupervisor, session_spec(name, opts))
  end

  defp session_spec(name, opts) do
    %{
      id: name,
      start: {El.Session.Api, :start_link, [{name, opts}]},
      restart: :temporary
    }
  end

  defp filter_session_opts(opts) do
    Keyword.drop(opts, [:registry, :supervisor, :monitor, :app])
  end

  def tell(name, message, opts \\ []) do
    session_api(opts).tell(name, message)
  end

  def ask(name, message, opts \\ []) do
    session_api(opts).ask(name, message)
  end

  def log(name, count \\ nil, opts \\ []) do
    case count do
      nil -> session_api(opts).log(name)
      _ -> session_api(opts).log(name, count)
    end
  end

  def clear(name, opts \\ []) do
    session_api(opts).clear(name)
  end

  def tell_ask(name, target, message, opts \\ []), do: session_api(opts).tell_ask(name, target, message)
  def ask_tell(name, target, message, opts \\ []), do: session_api(opts).ask_tell(name, target, message)
  def agent(name, opts \\ []), do: session_api(opts).agent(name)
  defp session_api(opts), do: Keyword.get(opts, :session_api, Application.get_env(:el, :session_api, El.Session.Api))

  def exit(name, opts \\ []) do
    El.Lifecycle.exit(name, :normal, opts)
  end

  def exit_pattern(pattern, opts \\ []) do
    ls()
    |> Enum.filter(&match_pattern?(&1, pattern))
    |> Enum.each(&El.exit(&1, opts))
  end

  def clear_pattern(pattern, opts \\ []) do
    ls() |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&El.clear(&1, opts))
  end

  def log_pattern(pattern, count, opts \\ []),
    do:
      ls() |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.flat_map(&log_entries(&1, count, opts))

  defp log_entries(name, count, opts) do
    name |> session_api(opts).log(count) |> filter_found()
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
