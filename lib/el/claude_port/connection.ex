defmodule El.ClaudePort.Connection do
  @behaviour El.Behaviours.ClaudePortConnection

  require Logger

  alias ClaudeCode.CLI.Input

  def open_port(state) do
    state.port_spawn_module.spawn(state.cli_resolver_module.resolve(state.cli_path, state.opts, state.resume_id), state)
  end

  def send_message(state, message) do
    session_id = session_id_or_default(state.session_id)
    ndjson = Input.user_message(message, session_id)
    state.port_module.command(state.port, ndjson <> "\n")
  end

  def session_id_or_default(nil), do: "default"
  def session_id_or_default(id), do: id

  def handle_ask(state, message, from) do
    case ensure_connected(state) do
      {:ok, connected_state} ->
        Logger.debug("ClaudePort connected, sending message")
        send_message(connected_state, message)
        {:noreply, %{connected_state | current_request_id: from}}

      {:error, reason} ->
        Logger.error("ClaudePort ensure_connected failed: #{inspect(reason)}")
        {:reply, {"(unavailable)", nil, nil}, state}
    end
  end

  def handle_connect(state) do
    apply_continue_result(open_port(state), state)
  end

  defp ensure_connected(%{port: nil} = state) do
    apply_ensure_result(open_port(state), state)
  end

  defp ensure_connected(state), do: {:ok, state}

  defp apply_continue_result({:ok, port}, state) do
    {:noreply, %{state | port: port, buffer: ""}}
  end

  defp apply_continue_result({:error, reason}, state) do
    Logger.error("Failed to open Claude port: #{inspect(reason)}")
    {:noreply, %{state | port: nil}}
  end

  defp apply_ensure_result({:ok, port}, state) do
    {:ok, %{state | port: port, buffer: ""}}
  end

  defp apply_ensure_result({:error, reason}, _state) do
    {:error, reason}
  end
end
