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
    restorer_module().restore_sessions(restorer_module().restore_opts())
    {:ok, pid}
  end

  @impl true
  def stop(_state) do
    dets_backend = Application.get_env(:el, :dets_backend, :dets)
    dets_backend.close(:session_meta)
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    message_store.close()
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

  defp restorer_module do
    Application.get_env(:el, :restorer_module, El.Session.Restorer)
  end

end
