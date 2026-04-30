defmodule El.Session.CastHandler do
  alias El.Session.Claude
  alias El.Session.Tell
  alias El.Session.Store
  alias El.Session.Router
  alias El.Session.Ask

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

  def handle({:complete_ask, from, message, response, ref, model}, state) do
    new_state = Ask.finalize_ask(state, from, ref, message, response, model)
    {:noreply, new_state}
  end

  def handle({:cast_store_relay, message, response}, state) do
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry)
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  def handle({:tell_ask, target, message}, state) do
    response = Router.process_tell_ask(state, target, message)
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry)
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end
end
