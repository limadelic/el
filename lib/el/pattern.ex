defmodule El.Pattern do
  @behaviour El.Behaviours.Pattern

  @impl true
  def restart(pattern, opts) do
    el = Keyword.get(opts, :el, El)
    ls(opts) |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&el.restart(&1, opts))
  end

  @impl true
  def exit(pattern, opts) do
    el = Keyword.get(opts, :el, El)
    ls(opts) |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&el.exit(&1, opts))
  end

  @impl true
  def clear(pattern, opts) do
    el = Keyword.get(opts, :el, El)
    ls(opts) |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&el.clear(&1, opts))
  end

  @impl true
  def log(pattern, count, opts) do
    ls(opts) |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.flat_map(&log_entries(&1, count, opts))
  end

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

  defp session_api(opts), do: Keyword.fetch!(opts, :session_api)

  defp ls(opts) do
    session_registry = Application.get_env(:el, :session_registry, El.Session.Registry)
    session_registry.list(opts)
  end
end
