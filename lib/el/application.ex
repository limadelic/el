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
    init_message_store()
    {:ok, pid} = Supervisor.start_link(children(), supervisor_opts())
    restore_sessions()
    {:ok, pid}
  end

  defp restore_sessions do
    el = Application.get_env(:el, :el_module, El)
    message_store = Application.get_env(:el, :message_store, El.MessageStore)

    message_store.session_names()
    |> Enum.each(fn name -> el.start(name) end)
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

  def init_message_store do
    dir = store_dir()
    path = Path.expand("#{dir}/messages.dets") |> String.to_charlist()
    File.mkdir_p!(Path.expand(dir))
    {:ok, _} = :dets.open_file(:message_store, file: path, type: :bag)
  end

  defp store_dir, do: store_dir(El.CLI.Daemon.dev?())
  defp store_dir(true), do: "~/.el/dev"
  defp store_dir(false), do: "~/.el"

  def delete_session_messages(name) do
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    message_store.delete(name)
  end

  def store_message(name, message_entry) do
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    message_store.insert(name, message_entry)
  end

  def load_messages(name) do
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    message_store.lookup(name)
  end

  def delete_message(name, entry) do
    message_store = Application.get_env(:el, :message_store, El.MessageStore)
    message_store.delete_entry(name, entry)
  end
end
