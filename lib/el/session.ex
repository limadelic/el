defmodule El.Session do
  use GenServer

  require Logger

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
    claude_module = Keyword.get(opts, :claude_module, El.ClaudeCode)
    task_module = Keyword.get(opts, :task_module, Task)
    alive_fn = Keyword.get(opts, :alive_fn, &El.Session.alive?/1)
    registry_module = Keyword.get(opts, :registry_module, Registry)
    start_result = start_claude(opts, claude_module)

    case start_result do
      {:error, reason} ->
        {:stop, reason}

      claude_pid ->
        messages = El.Application.load_messages(name)

        {:ok,
         %{
           name: name,
           claude_pid: claude_pid,
           messages: messages,
           pending_calls: [],
           claude_module: claude_module,
           task_module: task_module,
           alive_fn: alive_fn,
           registry_module: registry_module,
           opts: opts
         }}
    end
  end

  defp start_claude(opts, claude_module) do
    opts
    |> claude_module.start_link()
    |> handle_start_result()
  end

  defp handle_start_result({:ok, pid}), do: pid
  defp handle_start_result({:error, reason}), do: {:error, reason}

  defp maybe_respawn_claude(%{claude_pid: nil, opts: opts, claude_module: claude_module} = state) do
    case start_claude(opts, claude_module) do
      pid when is_pid(pid) -> %{state | claude_pid: pid}
      _ -> state
    end
  end

  defp maybe_respawn_claude(state), do: state

  @impl true
  def handle_cast({:tell, message}, state) do
    state = maybe_respawn_claude(state)
    routes = detect_routes(message)
    ref = make_ref()
    new_state = store_tell_immediate(state, message, ref, routes)
    process_tell(new_state, message, ref, routes)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:store_tell, ref, message, response}, state) do
    new_messages = replace_tell(state.messages, ref, message, response)
    new_state = %{state | messages: new_messages}
    El.Application.store_message(state.name, {"tell", message, response, %{}})
    routes = detect_routes(response)
    process_tell_response(state, response, routes)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:complete_ask, from, message, response}, state) do
    entry = {"ask", message, response, %{}}
    new_messages = state.messages ++ [entry]
    El.Application.store_message(state.name, entry)
    safe_reply(from, response)
    new_pending = List.delete(state.pending_calls, from)
    {:noreply, %{state | messages: new_messages, pending_calls: new_pending}}
  end

  @impl true
  def handle_cast({:store_relay, message, response}, state) do
    entry = {"relay", message, response, %{from: state.name}}
    El.Application.store_message(state.name, entry)
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  @impl true
  def handle_cast({:tell_ask, target, message}, state) do
    response = process_tell_ask(state, target, message)
    entry = {"relay", message, response, %{from: state.name}}
    El.Application.store_message(state.name, entry)

    new_state = %{state | messages: state.messages ++ [entry]}

    {:noreply, new_state}
  end

  defp process_tell(state, message, ref, []) do
    server_pid = self()
    task_module = Map.get(state, :task_module, Task)

    task_module.start(fn ->
      response = ask_claude(state.claude_pid, message)
      GenServer.cast(server_pid, {:store_tell, ref, message, response})
    end)
  end

  defp process_tell(state, message, _ref, routes) do
    Enum.each(routes, fn {target, payload} ->
      process_tell_route(state, message, target, payload)
    end)
  end

  defp process_tell_route(state, _message, target, _payload) when target == state.name do
    :ok
  end

  defp process_tell_route(state, message, target, payload) do
    alive_fn = Map.get(state, :alive_fn, &El.Session.alive?/1)
    process_tell_route_alive(state, message, target, payload, alive_fn.(target))
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

  defp process_tell_response_route(state, _response, target, _payload)
       when target == state.name do
    :ok
  end

  defp process_tell_response_route(state, response, target, payload) do
    alive_fn = Map.get(state, :alive_fn, &El.Session.alive?/1)
    process_tell_response_route_alive(state, response, target, payload, alive_fn.(target))
  end

  defp process_tell_response_route_alive(state, response, target, payload, true) do
    El.Session.tell(target, "[from #{state.name}] #{payload}")
    store_relay(state.name, response, "-> #{target}")
  end

  defp process_tell_response_route_alive(state, response, target, _payload, false) do
    store_relay(state.name, response, "#{target} is not running")
  end

  defp process_tell_ask(state, target, message) do
    alive_fn = Map.get(state, :alive_fn, &El.Session.alive?/1)
    process_tell_ask_alive(state, target, message, alive_fn.(target))
  end

  defp process_tell_ask_alive(state, target, message, true) do
    task_module = Map.get(state, :task_module, Task)

    task_module.start(fn ->
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
  def handle_call({:ask, message}, from, state) do
    state = maybe_respawn_claude(state)
    routes = detect_routes(message)
    valid_routes = Enum.filter(routes, fn {target, _payload} -> target != state.name end)
    new_state = %{state | pending_calls: [from | state.pending_calls]}
    spawn_ask(new_state, from, message, valid_routes)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:log, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_call({:ask_tell, target, message}, _from, state) do
    response = process_ask_tell(state, target, message)
    entry = {"relay", message, response, %{from: state.name}}
    El.Application.store_message(state.name, entry)

    new_state = %{state | messages: state.messages ++ [entry]}

    {:reply, response, new_state}
  end

  defp spawn_ask(state, from, message, valid_routes) do
    server_pid = self()
    task_module = Map.get(state, :task_module, Task)

    task_module.start(fn ->
      response =
        try do
          do_ask_work(state, message, valid_routes)
        rescue
          _ -> "(error)"
        catch
          :exit, _ -> "(error)"
          _, _ -> "(error)"
        end

      GenServer.cast(server_pid, {:complete_ask, from, message, response})
    end)
  end

  defp do_ask_work(state, message, []) do
    ask_claude(state.claude_pid, message)
  end

  defp do_ask_work(state, message, [{target, payload}]) do
    process_ask_single_route(state, message, target, payload)
  end

  defp do_ask_work(state, message, _multiple_routes) do
    ask_claude(state.claude_pid, message)
  end

  defp process_ask_single_route(state, message, target, payload) do
    alive_fn = Map.get(state, :alive_fn, &El.Session.alive?/1)
    process_ask_single_route_alive(state, message, target, payload, alive_fn.(target))
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
    alive_fn = Map.get(state, :alive_fn, &El.Session.alive?/1)
    process_ask_tell_alive(state, target, message, alive_fn.(target))
  end

  defp process_ask_tell_alive(state, target, message, true) do
    El.tell(target, "[from #{state.name}] #{message}")
    "-> #{target}"
  end

  defp process_ask_tell_alive(_state, target, _message, false) do
    "#{target} is not running"
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{claude_pid: pid} = state) do
    unless reason == :normal do
      Logger.error("Session #{state.name} - Claude process died: #{inspect(reason)}")
      El.Application.store_message(state.name, {"crash", "session died", inspect(reason), %{}})
    end

    Enum.each(state.pending_calls, fn from ->
      safe_reply(from, "(error)")
    end)

    {:noreply, %{state | claude_pid: nil, pending_calls: []}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    case reason do
      :normal -> :ok
      :shutdown -> :ok
      {:shutdown, _} -> :ok
      _ -> El.Application.store_message(state.name, {"crash", "Session crashed", inspect(reason), %{}})
    end

    :ok
  end

  defp safe_reply(from, response) do
    GenServer.reply(from, response)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
    _, _ -> :ok
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

  defp store_tell_immediate(state, message, ref, []) do
    entry = {"tell", message, "", %{ref: ref}}
    El.Application.store_message(state.name, entry)
    %{state | messages: state.messages ++ [entry]}
  end

  defp store_tell_immediate(state, _message, _ref, _routes), do: state

  defp replace_tell(messages, ref, message, response) do
    messages
    |> Enum.split_while(fn
      {"tell", _, "", %{ref: ^ref}} -> false
      _ -> true
    end)
    |> complete_tell(message, response)
  end

  defp complete_tell({before, [{_, _, _, _} | rest]}, message, response) do
    before ++ [{"tell", message, response, %{}} | rest]
  end

  defp complete_tell({messages, []}, message, response) do
    messages ++ [{"tell", message, response, %{}}]
  end

  defp via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end
end
