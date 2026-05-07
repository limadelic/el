defmodule El.Session.Claude.Opts do
  def build(rest, opts, _session_id) do
    rest
    |> add_resume(Keyword.has_key?(opts, :resume), opts)
    |> add_continue(Keyword.has_key?(opts, :continue), opts)
    |> ensure_setting_sources()
  end

  defp ensure_setting_sources(opts) do
    put_default_sources(Keyword.has_key?(opts, :setting_sources), opts)
  end

  defp put_default_sources(true, opts), do: opts
  defp put_default_sources(false, opts), do: Keyword.put(opts, :setting_sources, ["user", "project", "local"])

  defp add_resume(claude_opts, true, opts) do
    Keyword.put(claude_opts, :resume, Keyword.get(opts, :resume))
  end

  defp add_resume(claude_opts, false, _opts) do
    claude_opts
  end

  defp add_continue(claude_opts, true, opts) do
    Keyword.put(claude_opts, :continue, Keyword.get(opts, :continue))
  end

  defp add_continue(claude_opts, false, _opts) do
    claude_opts
  end
end
