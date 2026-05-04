defmodule El.Session.Router do
  def detect_routes(text) do
    Regex.scan(~r/^@(\w+)>\s*(.*)$/m, text, capture: :all_but_first)
    |> Enum.map(fn [target, payload] ->
      {String.to_atom(target), payload}
    end)
  end

  def envelope(name, payload) do
    "[from #{name}] #{payload}"
  end

  def route_if_alive(state, target, on_alive) do
    do_route(target, on_alive, state.alive_fn.(target))
  end

  defp do_route(target, on_alive, true) do
    on_alive.()
    "-> #{target}"
  end

  defp do_route(target, _on_alive, false) do
    "#{target} is not running"
  end

  def route_all_tells(state, message, routes) do
    Enum.each(routes, fn {target, payload} ->
      process_tell_route(state, message, target, payload)
    end)
  end

  defp process_tell_route(state, _message, target, _payload)
       when target == state.name do
    :ok
  end

  defp process_tell_route(state, message, target, payload) do
    route_if_alive(state, target, fn ->
      tell_route_target(state, message, target, payload)
    end)
  end

  defp tell_route_target(state, message, target, payload) do
    relay_payload = envelope(state.name, payload)
    state.session_api.cast_store_relay(target, relay_payload, "")
    state.session_api.cast_store_relay(state.name, message, "-> #{target}")
  end

  def process_tell_response(state, response, routes) do
    Enum.each(routes, fn {target, payload} ->
      process_tell_response_route(state, response, target, payload)
    end)
  end

  defp process_tell_response_route(state, _response, target, _payload)
       when target == state.name do
    :ok
  end

  defp process_tell_response_route(state, response, target, payload) do
    route_if_alive(state, target, fn ->
      state.session_api.tell(target, envelope(state.name, payload))
      state.session_api.cast_store_relay(state.name, response, "-> #{target}")
    end)
  end

  def process_tell_ask(state, target, message) do
    route_if_alive(state, target, fn ->
      state.task_module.start(fn ->
        state.el_module.ask(target, envelope(state.name, message))
      end)
    end)
  end

  def process_ask_tell(state, target, message) do
    route_if_alive(state, target, fn ->
      state.el_module.tell(target, envelope(state.name, message))
    end)
  end

  def filter_self_routes(routes, state) do
    Enum.filter(routes, fn {target, _} -> target != state.name end)
  end
end
