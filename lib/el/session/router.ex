defmodule El.Session.Router do
  alias El.Session.Registry

  def detect_routes(text) do
    Regex.scan(~r/^@(\w+)>\s*(.*)$/m, text, capture: :all_but_first)
    |> Enum.map(fn [target, payload] ->
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
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
    GenServer.cast(Registry.via_tuple(target), {:cast_store_relay, relay_payload, ""})
    cast_store_relay(state.name, message, "-> #{target}")
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
      El.Session.Api.tell(target, envelope(state.name, payload))
      cast_store_relay(state.name, response, "-> #{target}")
    end)
  end

  def process_tell_ask(state, target, message) do
    route_if_alive(state, target, fn ->
      state.task_module.start(fn ->
        El.ask(target, envelope(state.name, message))
      end)
    end)
  end

  def process_ask_tell(state, target, message) do
    route_if_alive(state, target, fn ->
      El.tell(target, envelope(state.name, message))
    end)
  end

  def filter_self_routes(routes, state) do
    Enum.filter(routes, fn {target, _} -> target != state.name end)
  end

  def cast_store_relay(sender_name, message, response) do
    pid = Registry.via_tuple(sender_name)
    GenServer.cast(pid, {:cast_store_relay, message, response})
  end
end
