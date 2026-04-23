defmodule El.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    :ok = Application.ensure_started(:sasl)
    init_message_store()
    Supervisor.start_link(children(), supervisor_opts())
  end

  def children do
    [
      {Registry, keys: :unique, name: El.Registry},
      {DynamicSupervisor, name: El.SessionSupervisor, max_restarts: 10, max_seconds: 30}
    ]
  end

  def supervisor_opts do
    [strategy: :one_for_one, name: El.Supervisor]
  end

  def init_message_store do
    path = Path.expand("~/.el/messages.dets") |> String.to_charlist()
    File.mkdir_p!(Path.expand("~/.el"))
    {:ok, _} = :dets.open_file(:message_store, file: path, type: :bag)
  end

  def delete_session_messages(name) do
    :dets.delete(:message_store, name)
    :ok
  end

  def store_message(name, message_entry) do
    :dets.insert(:message_store, {name, message_entry})
    :ok
  end

  def load_messages(name) do
    :dets.lookup(:message_store, name)
    |> Enum.map(fn {_key, entry} -> entry end)
  end
end
