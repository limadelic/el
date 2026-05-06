defmodule El.Application do
  @moduledoc false
  use Application

  @supervisor_opts [
    strategy: :one_for_one,
    name: El.Supervisor,
    max_restarts: 100,
    max_seconds: 60
  ]

  @impl true
  def start(_type, _args) do
    init_module().init_message_store(init_module().message_store_opts())
    {:ok, pid} = Supervisor.start_link(children(), supervisor_opts())
    restore_sessions(restore_opts())
    {:ok, pid}
  end

  defp restore_opts do
    [
      el_module: Application.get_env(:el, :el_module, El),
      session_meta: Application.get_env(:el, :session_meta, El.SessionMeta),
      message_store: Application.get_env(:el, :message_store, El.MessageStore)
    ]
  end

  @impl true
  def stop(_state) do
    dets_backend = Application.get_env(:el, :dets_backend, :dets)
    dets_backend.close(:session_meta)
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    message_store.close()
  end

  def restore_sessions(opts \\ []) do
    ctx = restore_context(opts)
    ctx.message_store.session_names()
    |> Enum.each(&restore_session(&1, ctx.el, ctx.session_meta, ctx.deps))
  end

  defp restore_context(opts) do
    Map.merge(opts_modules(opts), %{deps: El.Deps.production()})
  end

  defp opts_modules(opts) do
    %{
      el: Keyword.fetch!(opts, :el_module),
      message_store: Keyword.fetch!(opts, :message_store),
      session_meta: Keyword.fetch!(opts, :session_meta)
    }
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

  def children do
    [
      {Registry, keys: :unique, name: El.Registry},
      {DynamicSupervisor, session_supervisor_opts()}
    ]
  end

  defp session_supervisor_opts do
    [name: El.SessionSupervisor, max_restarts: 50, max_seconds: 60]
  end

  def supervisor_opts, do: @supervisor_opts

  defp init_module do
    Application.get_env(:el, :init_module, El.MessageStore.Init)
  end

end
