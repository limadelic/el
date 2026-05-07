defmodule El.Session.Lifecycle.Restorer do
  @behaviour El.Session.Behaviours.Restorer

  def restore_opts do
    [
      el_module: Application.get_env(:el, :el_module, El),
      session_meta: Application.get_env(:el, :session_meta, El.Session.Meta),
      message_store: Application.get_env(:el, :message_store, El.MessageStore)
    ]
  end

  def restore_sessions(opts \\ []) do
    ctx = restore_context(opts)
    ctx.message_store.session_names()
    |> Enum.each(&restore_session(&1, ctx.el, ctx.session_meta, ctx.deps))
  end

  defp opts_modules(opts) do
    %{
      el: Keyword.fetch!(opts, :el_module),
      message_store: Keyword.fetch!(opts, :message_store),
      session_meta: Keyword.fetch!(opts, :session_meta)
    }
  end

  defp restore_context(opts) do
    Map.merge(opts_modules(opts), %{deps: El.Deps.production()})
  end

  defp restore_session(name, el, _session_meta, deps, {:ok, session_id, agent, model}) do
    opts = [resume: session_id, agent: agent, model: model] ++ deps
    el.start(name, opts)
  end

  defp restore_session(name, el, _session_meta, deps, {:error, :not_found}) do
    el.start(name, deps)
  end

  defp restore_session(name, el, session_meta, deps) do
    restore_session(name, el, session_meta, deps, session_meta.lookup(name))
  end
end
