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
    file_system = Application.get_env(:el, :file_system, El.FileSystemImpl)
    dets_backend = Application.get_env(:el, :dets_backend, :dets)
    init_message_store(file_system: file_system, dets_backend: dets_backend)
    {:ok, pid} = Supervisor.start_link(children(), supervisor_opts())
    el_module = Application.get_env(:el, :el_module, El)
    session_meta = Application.get_env(:el, :session_meta, El.SessionMeta)
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    restore_sessions(el_module: el_module, session_meta: session_meta, message_store: message_store)
    {:ok, pid}
  end

  @impl true
  def stop(_state) do
    dets_backend = Application.get_env(:el, :dets_backend, :dets)
    dets_backend.close(:session_meta)
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    message_store.close()
  end

  def restore_sessions(opts \\ []) do
    el = Keyword.fetch!(opts, :el_module)
    message_store = Keyword.fetch!(opts, :message_store)
    session_meta = Keyword.fetch!(opts, :session_meta)

    message_store.session_names()
    |> Enum.each(&restore_session(&1, el, session_meta))
  end

  defp restore_session(name, el, _session_meta, {:ok, session_id, agent, model}) do
    opts = [resume: session_id, agent: agent, model: model]
    el.start(name, opts)
  end

  defp restore_session(name, el, _session_meta, {:error, :not_found}) do
    el.start(name, [])
  end

  defp restore_session(name, el, session_meta) do
    restore_session(name, el, session_meta, session_meta.lookup(name))
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

  def init_message_store(opts \\ []) do
    dir = store_dir()
    messages_path = Path.expand("#{dir}/messages.dets") |> String.to_charlist()
    session_meta_path = Path.expand("#{dir}/session_meta.dets") |> String.to_charlist()
    file_system = opts[:file_system] || Application.get_env(:el, :file_system, El.FileSystemImpl)
    file_system.mkdir_p!(Path.expand(dir))
    dets_backend = opts[:dets_backend] || Application.get_env(:el, :dets_backend, :dets)
    {:ok, _} = dets_backend.open_file(:message_store, file: messages_path, type: :bag)
    {:ok, _} = dets_backend.open_file(:session_meta, file: session_meta_path, type: :bag)
  end

  defp store_dir do
    daemon = Application.get_env(:el, :daemon, El.CLI.Daemon)
    store_dir(daemon.dev?())
  end

  defp store_dir(true), do: "~/.el/dev"
  defp store_dir(false), do: "~/.el"

  def delete_session_messages(name, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.delete(name)
  end

  def store_message(name, message_entry, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.insert(name, message_entry)
  end

  def load_messages(name, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.lookup(name)
  end

  def delete_message(name, entry, opts \\ []) do
    ms = Keyword.fetch!(opts, :message_store)
    ms.delete_entry(name, entry)
  end
end
