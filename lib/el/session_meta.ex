defmodule El.SessionMeta do
  @callback insert(term(), term(), term()) :: term()
  @callback lookup(term()) :: term()
  @callback delete(term()) :: term()
  @callback close() :: term()

  def insert(name, agent, session_id) do
    backend = Application.get_env(:el, :dets_backend, El.DetsBackend)
    backend.insert(:session_meta, {name, session_id, agent})
    :ok
  end

  def lookup(name) do
    backend = Application.get_env(:el, :dets_backend, El.DetsBackend)

    backend.lookup(:session_meta, name)
    |> match_session()
  end

  defp match_session([{_name, session_id, agent}]), do: {:ok, session_id, agent}
  defp match_session([]), do: {:error, :not_found}

  def delete(name) do
    backend = Application.get_env(:el, :dets_backend, El.DetsBackend)
    backend.delete(:session_meta, name)
    :ok
  end

  def close do
    :dets.close(:session_meta)
  end
end
