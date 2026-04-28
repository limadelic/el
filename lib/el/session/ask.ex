defmodule El.Session.Ask do
  alias El.Session.Router
  alias El.Session.Store
  alias El.Session.Claude

  def prepare_ask(state, from, message) do
    routes = Router.detect_routes(message)
    valid_routes = Router.filter_self_routes(routes, state)
    new_state = %{state | pending_calls: [from | state.pending_calls]}
    Store.store_ask_immediate(new_state, message, valid_routes)
  end

  def spawn_ask(state, from, message, valid_routes, ref, server_pid) do
    state.task_module.start(fn ->
      spawn_ask_task(state, {from, message, ref}, valid_routes, server_pid)
    end)
  end

  defp spawn_ask_task(state, ask_info, valid_routes, server_pid) do
    {from, message, ref} = ask_info
    response = Claude.ask_work(state.claude_pid, message, valid_routes)
    GenServer.cast(server_pid, {:complete_ask, from, message, response, ref})
  end

  def finalize_ask(state, from, ref, message, response) do
    Store.delete_ask_entry(state, message, ref)
    Store.store_ask_entry(state, {"ask", message, response, %{}})
    Claude.safe_reply(from, response)
    finalize_ask_state(state, from, ref, message, response)
  end

  defp finalize_ask_state(state, from, ref, message, response) do
    new_messages = Store.replace_ask(state.messages, ref, message, response)
    new_pending = List.delete(state.pending_calls, from)
    %{state | messages: new_messages, pending_calls: new_pending}
  end

  def reset_session(state) do
    state
    |> clear_messages()
    |> start_new_session()
  end

  defp clear_messages(state) do
    state.store_module.delete_session_messages(state.name)
    %{state | messages: []}
  end

  defp start_new_session(state) do
    session_id = El.Session.Id.generate_session_id()
    opts = Keyword.put(state.opts, :session_id, session_id)
    pid = Claude.start(state.claude_module, opts)
    %{state | claude_pid: pid, claude_opts: opts, session_id: session_id}
  end
end
