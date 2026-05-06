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

  defdelegate opts_modules(opts), to: El.SessionRestorer
  defdelegate restore_context(opts), to: El.SessionRestorer
  defdelegate restore_session(name, el, session_meta, deps), to: El.SessionRestorer
  defdelegate restore_session(name, el, session_meta, deps, lookup_result), to: El.SessionRestorer

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
