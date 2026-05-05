defmodule El do
  def app(opts \\ []), do: Keyword.fetch!(opts, :app)
  def session(opts \\ []), do: Keyword.fetch!(opts, :session)
  def registry(opts \\ []), do: Keyword.fetch!(opts, :registry)
  def supervisor(opts \\ []), do: Keyword.fetch!(opts, :supervisor)
  def monitor(opts \\ []), do: Keyword.fetch!(opts, :monitor)

  def start(name, opts \\ []) when is_atom(name) do
    start_if_needed(name, opts, registry(opts).lookup(El.Registry, name))
  end

  defp start_if_needed(_name, _opts, [{_pid, _}]) do
    :already_running
  end

  defp start_if_needed(name, opts, []) do
    filtered_opts = filter_session_opts(opts)
    start_session_child(name, opts, filtered_opts)
    :created
  end

  defp start_session_child(name, opts, filtered_opts) do
    supervisor(opts).start_child(El.SessionSupervisor, session_spec(name, filtered_opts))
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
  defp session_api(opts), do: Keyword.fetch!(opts, :session_api)

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

  def ls(opts \\ []) do
    registry(opts).select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end
end
