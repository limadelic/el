defmodule El.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    init_message_store()
    Supervisor.start_link(children(), supervisor_opts())
  end

  def children do
    [
      {Registry, keys: :unique, name: El.Registry},
      {DynamicSupervisor, name: El.SessionSupervisor, max_restarts: 50, max_seconds: 60}
    ]
  end

  def supervisor_opts do
    [strategy: :one_for_one, name: El.Supervisor, max_restarts: 100, max_seconds: 60]
  end

  def init_message_store do
    path = Path.expand("~/.el/messages.dets") |> String.to_charlist()
    File.mkdir_p!(Path.expand("~/.el"))
    {:ok, _} = :dets.open_file(:message_store, file: path, type: :bag)
  end

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
end
