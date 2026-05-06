defmodule El.ClaudePort.Buffer do
  def process(data, state) do
    new_state = %{state | buffer: state.buffer <> data}
    extract(new_state)
  end

  defp extract(%{current_request_id: nil} = state) do
    {:noreply, state}
  end

  defp extract(state) do
    case parser().try_extract_result(state.buffer, state.session_id) do
      :incomplete ->
        {:noreply, state}

      {:ok, result, remaining_buffer} ->
        {:reply, state.current_request_id, result, %{state | buffer: remaining_buffer, current_request_id: nil}}
    end
  end

  defp parser, do: Application.get_env(:el, :parser, El.ClaudePort.Parser)
end
