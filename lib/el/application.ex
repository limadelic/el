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
    :ets.new(:message_store, [:named_table, :public])
  end

  def delete_session_messages(name) do
    key = {name, :messages}
    :ets.delete(:message_store, key)
    :ok
  end

  def store_message(name, message_entry) do
    key = {name, :messages}
    existing = :ets.lookup(:message_store, key)

    case existing do
      [{^key, messages}] ->
        :ets.insert(:message_store, {key, messages ++ [message_entry]})

      [] ->
        :ets.insert(:message_store, {key, [message_entry]})
    end

    :ok
  end

  def load_messages(name) do
    key = {name, :messages}

    case :ets.lookup(:message_store, key) do
      [{^key, messages}] -> messages
      [] -> []
    end
  end
end
