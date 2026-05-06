defmodule El.SessionRestorer do
  def opts_modules(opts) do
    %{
      el: Keyword.fetch!(opts, :el_module),
      message_store: Keyword.fetch!(opts, :message_store),
      session_meta: Keyword.fetch!(opts, :session_meta)
    }
  end

  def restore_context(opts) do
    Map.merge(opts_modules(opts), %{deps: El.Deps.production()})
  end

  def restore_session(name, el, _session_meta, deps, {:ok, session_id, agent, model}) do
    opts = [resume: session_id, agent: agent, model: model] ++ deps
    el.start(name, opts)
  end

  def restore_session(name, el, _session_meta, deps, {:error, :not_found}) do
    el.start(name, deps)
  end

  def restore_session(name, el, session_meta, deps) do
    restore_session(name, el, session_meta, deps, session_meta.lookup(name))
  end
end
