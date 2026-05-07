defmodule El do
  @behaviour El.Behaviours.El

  @impl true
  def start(name, opts \\ []) when is_atom(name) do
    start_if_needed(name, opts, El.Deps.registry(opts).lookup(El.Registry, name))
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
    El.Deps.supervisor(opts).start_child(El.SessionSupervisor, session_spec(name, filtered_opts))
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

  @impl true
  def tell(name, message, opts \\ []) do
    session_api(opts).tell(name, message)
  end

  @impl true
  def ask(name, message, opts \\ []) do
    session_api(opts).ask(name, message)
  end

  @impl true
  def log(name, count \\ nil, opts \\ [])
  def log(name, nil, opts), do: session_api(opts).log(name)
  def log(name, count, opts), do: session_api(opts).log(name, count)

  @impl true
  def clear(name, opts \\ []) do
    session_api(opts).clear(name)
  end

  @impl true
  def agent(name, opts \\ []), do: session_api(opts).agent(name)
  defp session_api(opts), do: Keyword.fetch!(opts, :session_api)

  @impl true
  def exit(name, opts \\ []) do
    El.Lifecycle.exit(name, :normal, opts)
  end

  @impl true
  def exit_pattern(pattern, opts \\ []) do
    ls(opts)
    |> Enum.filter(&match_pattern?(&1, pattern))
    |> Enum.each(&El.exit(&1, opts))
  end

  @impl true
  def clear_pattern(pattern, opts \\ []) do
    ls(opts) |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&El.clear(&1, opts))
  end

  @impl true
  def log_pattern(pattern, count, opts \\ []),
    do:
      ls(opts) |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.flat_map(&log_entries(&1, count, opts))

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

  @impl true
  def ls(opts \\ []) do
    session_registry = Keyword.get(opts, :session_registry, El.Session.Registry)
    session_registry.list(opts)
  end
end
