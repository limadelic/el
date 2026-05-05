defmodule El.SessionMeta do
  @callback insert(term(), term(), term(), term()) :: term()
  @callback lookup(term()) :: term()
  @callback delete(term()) :: term()
  @callback close() :: term()

  def insert(name, agent, session_id, model \\ nil, deps \\ []) do
    backend = dets_backend(deps)
    backend.insert(:session_meta, {name, session_id, agent, model})
    :ok
  end

  def lookup(name, deps \\ []) do
    backend = dets_backend(deps)

    backend.lookup(:session_meta, name)
    |> match_session()
  end

  defp match_session([{_name, session_id, agent, model}]), do: {:ok, session_id, agent, model}
  defp match_session([]), do: {:error, :not_found}

  def delete(name, deps \\ []) do
    backend = dets_backend(deps)
    backend.delete(:session_meta, name)
    :ok
  end

  def close(deps \\ []) do
    backend = dets_backend(deps)
    backend.close(:session_meta)
  end

  defp dets_backend(deps), do: Keyword.get(deps, :dets_backend, El.DetsBackend)
end
