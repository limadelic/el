defmodule El.Session.CallHandler do
  alias El.Session.Claude
  alias El.Session.Ask
  alias El.Session.Router
  alias El.Session.Store

  def handle({:ask, message}, from, state) do
    state = Claude.maybe_respawn_claude(state)
    {ref, ask_state} = Ask.prepare_ask(state, from, message)
    Ask.spawn_ask(ask_state, from, message, Router.detect_routes(message), ref, self())
    {:noreply, ask_state}
  end

  def handle({:ask_tell, target, message}, _from, state) do
    response = Router.process_ask_tell(state, target, message)
    entry = Store.build_relay_entry(message, response, state)
    {:reply, response, Store.store_relay_entry(state, entry)}
  end

  def handle(:clear, _from, state) do
    Claude.stop_claude(state.claude_pid)
    Ask.reset_session(state) |> reply_ok()
  end

  defp reply_ok(new_state) do
    {:reply, :ok, new_state}
  end
end
