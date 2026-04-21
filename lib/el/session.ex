defmodule El.Session do
  use GenServer

  def start_link({name, session_opts}, _opts) do
    GenServer.start_link(__MODULE__, {name, session_opts}, name: via_tuple(name))
  end
  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, {name, opts}, name: via_tuple(name))
  end
  def start_link({name, session_opts}) do
    GenServer.start_link(__MODULE__, {name, session_opts}, name: via_tuple(name))
  end
  def start_link(name) do
    GenServer.start_link(__MODULE__, {name, []}, name: via_tuple(name))
  end

  def tell(name, message) do
    GenServer.cast(via_tuple(name), {:tell, message})
  end

  def ask(name, message) do
    GenServer.call(via_tuple(name), {:ask, message}, :infinity)
  end

  def log(name) do
    GenServer.call(via_tuple(name), :log, :infinity)
  end

  def tell_ask(name, target, message) do
    GenServer.cast(via_tuple(name), {:tell_ask, target, message})
  end

  def ask_tell(name, target, message) do
    GenServer.call(via_tuple(name), {:ask_tell, target, message}, :infinity)
  end

  def detect_routes(text) do
    Regex.scan(~r/^@(\w+)>\s*(.*)$/m, text, capture: :all_but_first)
    |> Enum.map(fn [target, payload] ->
      {String.to_atom(target), payload}
    end)
  end

  def alive?(name) do
    match?([{_pid, _}], Registry.lookup(El.Registry, name))
  end

  @impl true
  def init({name, opts}) do
    Process.flag(:trap_exit, true)
    claude_pid = start_claude(opts)
    {:ok, %{name: name, claude_pid: claude_pid, messages: []}}
  end

  defp start_claude(opts) do
    safe_start_code(opts)
  rescue
    _ -> nil
  catch
    :exit, _ -> nil
    _, _ -> nil
  end

  defp safe_start_code(opts) do
    opts
    |> El.ClaudeCode.start_link()
    |> handle_start_result()
  end

  defp handle_start_result({:ok, pid}), do: pid
  defp handle_start_result({:error, _reason}), do: nil

  @impl true
  def handle_cast({:tell, message}, state) do
    routes = detect_routes(message)
    process_tell(state, message, routes)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:store_tell, message, response}, state) do
    new_state = %{state | messages: state.messages ++ [{"tell", message, response, %{}}]}
    routes = detect_routes(response)
    process_tell_response(state, response, routes)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:store_relay, message, response}, state) do
    {:noreply,
     %{state | messages: state.messages ++ [{"relay", message, response, %{from: state.name}}]}}
  end

  @impl true
  def handle_cast({:tell_ask, target, message}, state) do
    response = process_tell_ask(state, target, message)
    new_state = %{
      state
      | messages: state.messages ++ [{"relay", message, response, %{from: state.name}}]
    }
    {:noreply, new_state}
  end

  defp process_tell(state, message, []) do
    server_pid = self()
    Task.start(fn ->
      response = ask_claude(state.claude_pid, message)
      GenServer.cast(server_pid, {:store_tell, message, response})
    end)
  end

  defp process_tell(state, message, routes) do
    Enum.each(routes, fn {target, payload} ->
      process_tell_route(state, message, target, payload)
    end)
  end

  defp process_tell_route(state, _message, target, _payload) when target == state.name do
    :ok
  end

  defp process_tell_route(state, message, target, payload) do
    process_tell_route_alive(state, message, target, payload, El.Session.alive?(target))
  end

  defp process_tell_route_alive(state, message, target, payload, true) do
    GenServer.cast(
      via_tuple(target),
      {:store_relay, "[from #{state.name}] #{payload}", ""}
    )
    store_relay(state.name, message, "-> #{target}")
  end

  defp process_tell_route_alive(state, message, target, _payload, false) do
    store_relay(state.name, message, "#{target} is not running")
  end

  defp process_tell_response(state, response, routes) do
    Enum.each(routes, fn {target, payload} ->
      process_tell_response_route(state, response, target, payload)
    end)
  end

  defp process_tell_response_route(state, _response, target, _payload) when target == state.name do
    :ok
  end

  defp process_tell_response_route(state, response, target, payload) do
    process_tell_response_route_alive(state, response, target, payload, El.Session.alive?(target))
  end

  defp process_tell_response_route_alive(state, response, target, payload, true) do
    El.Session.tell(target, "[from #{state.name}] #{payload}")
    store_relay(state.name, response, "-> #{target}")
  end

  defp process_tell_response_route_alive(state, response, target, _payload, false) do
    store_relay(state.name, response, "#{target} is not running")
  end

  defp process_tell_ask(state, target, message) do
    process_tell_ask_alive(state, target, message, El.Session.alive?(target))
  end

  defp process_tell_ask_alive(state, target, message, true) do
    Task.start(fn ->
      El.ask(target, "[from #{state.name}] #{message}")
    end)
    "-> #{target}"
  end

  defp process_tell_ask_alive(_state, target, _message, false) do
    "#{target} is not running"
  end

  defp store_relay(sender_name, message, response) do
    pid = via_tuple(sender_name)
    GenServer.cast(pid, {:store_relay, message, response})
  end

  @impl true
  def handle_call({:ask, message}, _from, state) do
    routes = detect_routes(message)
    valid_routes = Enum.filter(routes, fn {target, _payload} -> target != state.name end)
    {response, new_state} = process_ask(state, message, valid_routes)
    {:reply, response, new_state}
  end

  @impl true
  def handle_call(:log, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_call({:ask_tell, target, message}, _from, state) do
    response = process_ask_tell(state, target, message)
    new_state = %{
      state
      | messages: state.messages ++ [{"relay", message, response, %{from: state.name}}]
    }
    {:reply, response, new_state}
  end

  defp process_ask(state, message, []) do
    response = ask_claude(state.claude_pid, message)
    new_state = %{state | messages: state.messages ++ [{"ask", message, response, %{}}]}
    {response, new_state}
  end

  defp process_ask(state, message, [{target, payload}]) do
    response = process_ask_single_route(state, message, target, payload)
    new_state = %{state | messages: state.messages ++ [{"ask", message, response, %{}}]}
    {response, new_state}
  end

  defp process_ask(state, message, _multiple_routes) do
    response = ask_claude(state.claude_pid, message)
    new_state = %{state | messages: state.messages ++ [{"ask", message, response, %{}}]}
    {response, new_state}
  end

  defp process_ask_single_route(state, message, target, payload) do
    process_ask_single_route_alive(state, message, target, payload, El.Session.alive?(target))
  end

  defp process_ask_single_route_alive(state, message, target, payload, true) do
    relay_msg = "[from #{state.name}] #{payload}"
    GenServer.cast(via_tuple(target), {:store_relay, relay_msg, ""})
    store_relay(state.name, message, "-> #{target}")
    "-> #{target}"
  end

  defp process_ask_single_route_alive(state, message, target, _payload, false) do
    store_relay(state.name, message, "#{target} is not running")
    "#{target} is not running"
  end

  defp process_ask_tell(state, target, message) do
    process_ask_tell_alive(state, target, message, El.Session.alive?(target))
  end

  defp process_ask_tell_alive(state, target, message, true) do
    El.tell(target, "[from #{state.name}] #{message}")
    "-> #{target}"
  end

  defp process_ask_tell_alive(_state, target, _message, false) do
    "#{target} is not running"
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, %{claude_pid: pid} = state) do
    {:noreply, %{state | claude_pid: nil}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp ask_claude(nil, _message) do
    "(ClaudeCode unavailable)"
  end

  defp ask_claude(claude_pid, message) do
    safe_stream_claude(claude_pid, message)
  rescue
    _ -> "(ClaudeCode unavailable)"
  catch
    :exit, _ -> "(ClaudeCode unavailable)"
    _, _ -> "(ClaudeCode unavailable)"
  end

  defp safe_stream_claude(claude_pid, message) do
    claude_pid
    |> El.ClaudeCode.stream(message)
    |> ClaudeCode.Stream.text_content()
    |> Enum.join()
  end

  defp via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end
end
