defmodule El.Session.Tell do
  alias El.Session.Router
  alias El.Session.Store
  alias El.Session.Claude

  def tell_impl(state, message) do
    routes = Router.detect_routes(message)
    ref = make_ref()
    new_state = Store.store_tell_immediate(state, message, ref, routes)
    process_tell(new_state, message, ref, routes)
    {:noreply, new_state}
  end

  def process_tell(state, message, ref, []) do
    spawn_tell_task(state, message, ref)
  end

  def process_tell(state, message, _ref, routes) do
    Router.route_all_tells(state, message, routes)
  end

  defp spawn_tell_task(state, message, ref) do
    server_pid = self()

    state.task_module.start(fn ->
      process_tell_task(state, message, ref, server_pid)
    end)
  end

  defp process_tell_task(state, message, ref, server_pid) do
    response = Claude.ask(state.claude_pid, message)
    GenServer.cast(server_pid, {:store_tell, ref, message, response})
  end
end
