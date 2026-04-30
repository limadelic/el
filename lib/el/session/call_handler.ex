defmodule El.Session.CallHandler do
  alias El.Session.Claude
  alias El.Session.Ask
  alias El.Session.Router
  alias El.Session.Store

  def handle({:ask, message}, from, state) do
    state = Claude.maybe_respawn_claude(state)
    {ref, ask_state} = Ask.prepare_ask(state, from, message)
    routes = Router.detect_routes(message)
    Ask.spawn_ask(ask_state, {from, message, ref}, routes, self())
    {:noreply, ask_state}
  end

  def handle({:ask_tell, target, message}, _from, state) do
    response = Router.process_ask_tell(state, target, message)
    entry = Store.build_relay_entry(message, response, state)
    {:reply, response, Store.store_relay_entry(state, entry)}
  end

  def handle(:agent, _from, state) do
    {:reply, Keyword.get(state.opts, :agent), state}
  end

  def handle(:info, _from, state) do
    info = build_info(state.messages)
    {:reply, info, state}
  end

  def handle(:clear, _from, state) do
    Claude.stop_claude(state.claude_pid)
    Ask.reset_session(state) |> reply_ok()
  end

  defp build_info([]) do
    %{messages: 0, last_prompt: nil, last_response: nil, model: nil}
  end

  defp build_info(messages) do
    %{messages: length(messages)} |> add_last_message(List.last(messages))
  end

  defp add_last_message(info, {_type, prompt, response, metadata}) do
    Map.merge(info, %{last_prompt: prompt, last_response: response, model: Map.get(metadata, :model)})
  end

  defp reply_ok(new_state) do
    {:reply, :ok, new_state}
  end
end
