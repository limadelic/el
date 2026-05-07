defmodule El.Session.Handlers.Call do
  alias El.Session.Claude.Driver
  alias El.Session.Handlers.Router

  def handle({:ask, message}, from, state) do
    state = Driver.maybe_respawn_claude(state)
    {ref, ask_state} = state.ask_module.prepare_ask(state, from, message)
    routes = Router.detect_routes(message)
    ask_state.ask_module.spawn_ask(ask_state, {from, message, ref}, routes, self())
    {:noreply, ask_state}
  end

  def handle(:agent, _from, state) do
    {:reply, Keyword.get(state.opts, :agent), state}
  end

  def handle(:info, _from, state) do
    info = build_info(state.messages, state.session_id, state.cwd)
    {:reply, info, state}
  end

  def handle(:clear, _from, state) do
    Driver.stop_claude(state.claude_pid)
    state.ask_module.reset_session(state) |> reply_ok()
  end

  defp build_info([], session_id, cwd) do
    %{messages: 0, last_prompt: nil, last_response: nil, model: nil, id: session_id, cwd: cwd}
  end

  defp build_info(messages, session_id, cwd) do
    %{messages: length(messages), id: session_id, cwd: cwd} |> add_last_message(List.last(messages))
  end

  defp add_last_message(info, {_type, prompt, response, metadata}) do
    Map.merge(info, %{last_prompt: prompt, last_response: response, model: Map.get(metadata, :model)})
  end

  defp reply_ok(new_state) do
    {:reply, :ok, new_state}
  end
end
