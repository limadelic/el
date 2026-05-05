defmodule El.Session.CastHandler do
  alias El.Session.Claude
  alias El.Session.Tell
  alias El.Session.Store
  alias El.Session.Router

  def handle({:tell, message}, state) do
    state = Claude.maybe_respawn_claude(state)
    Tell.tell_impl(state, message)
  end

  def handle({:store_tell, ref, message, response}, state) do
    new_state = Store.complete_tell_entry(state, ref, message, response)
    routes = Router.detect_routes(response)
    Router.process_tell_response(state, response, routes)
    {:noreply, new_state}
  end

  def handle({:complete_ask, from, message, response, ref, model, nil}, state) do
    new_state = state.ask_module.finalize_ask(state, from, ref, message, response, model)
    {:noreply, new_state}
  end

  def handle({:complete_ask, from, message, response, ref, model, session_id}, state) do
    ask = %{from: from, message: message, response: response, ref: ref, model: model}
    updated_state = build_updated_state(state, ask, session_id)
    persist_session_meta(updated_state, session_id, model)
    {:noreply, updated_state}
  end

  def handle({:cast_store_relay, message, response}, state) do
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry, message_store: state.opts[:message_store])
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  def handle({:tell_ask, target, message}, state) do
    response = Router.process_tell_ask(state, target, message)
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry, message_store: state.opts[:message_store])
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  defp build_updated_state(state, ask, session_id) do
    new_state = state.ask_module.finalize_ask(state, ask.from, ask.ref, ask.message, ask.response, ask.model)
    %{new_state | session_id: session_id}
  end

  defp persist_session_meta(state, session_id, model) do
    session_meta = Map.get(state, :session_meta, El.SessionMeta)
    session_meta.insert(state.name, agent_from(state), session_id, persisted_model(state, model))
  end

  defp agent_from(state), do: Keyword.get(state.opts, :agent)

  defp persisted_model(state, model) do
    resolve_model(Keyword.get(state.opts, :model), model)
  end

  defp resolve_model(nil, model), do: model
  defp resolve_model(explicit, _model), do: explicit
end
