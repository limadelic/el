defmodule El.Session do
  use GenServer

  require Logger

  def start_link({name, session_opts}) do
    opts = [name: via_tuple(name)]
    GenServer.start_link(__MODULE__, {name, session_opts}, opts)
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

  def log(name, count) do
    GenServer.call(via_tuple(name), {:log, count}, :infinity)
  end

  def clear(name) do
    GenServer.call(via_tuple(name), :clear)
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
    {session_id, rest} = extract_resume_or_id(opts)
    {:ok, build_state(name, opts, rest, session_id), {:continue, :start_claude}}
  end

  defp extract_resume_or_id(opts) do
    {resume, rest} = Keyword.pop(opts, :resume)
    {session_id(resume), rest}
  end

  defp session_id(nil), do: generate_session_id()
  defp session_id(id), do: id

  defp build_state(name, opts, rest, session_id) do
    %{
      name: name,
      claude_pid: nil,
      session_id: session_id,
      messages: [],
      pending_calls: [],
      claude_module: Keyword.get(opts, :claude_module, El.ClaudeCode),
      task_module: Keyword.get(opts, :task_module, Task),
      alive_fn: Keyword.get(opts, :alive_fn, &El.Session.alive?/1),
      registry_module: Keyword.get(opts, :registry_module, Registry),
      store_module: Keyword.get(opts, :store_module, El.Application),
      opts: opts,
      claude_opts: Keyword.put(rest, :session_id, session_id)
    }
  end

  @impl true
  def handle_continue(:start_claude, state) do
    messages = state.store_module.load_messages(state.name)
    claude_pid = safe_start_claude(state.claude_module, state.claude_opts)
    {:noreply, %{state | claude_pid: claude_pid, messages: messages}}
  end

  defp maybe_respawn_claude(%{claude_pid: nil} = state) do
    opts_with_resume = resume_opts(state.opts, state.session_id)
    pid = safe_start_claude(state.claude_module, opts_with_resume)
    %{state | claude_pid: pid}
  end

  defp maybe_respawn_claude(%{claude_pid: pid} = state) when is_pid(pid) do
    handle_claude_pid_state(state, Process.alive?(pid))
  end

  defp resume_opts(opts, session_id) do
    opts
    |> Keyword.put(:session_id, session_id)
    |> Keyword.put(:resume, session_id)
  end

  defp handle_claude_pid_state(state, true), do: state

  defp handle_claude_pid_state(state, false) do
    maybe_respawn_claude(%{state | claude_pid: nil})
  end

  defp safe_start_claude(claude_module, opts) do
    start_claude_safe(claude_module.start_link(opts))
  end

  defp start_claude_safe({:ok, pid}), do: pid
  defp start_claude_safe(_), do: nil

  defp envelope(name, payload) do
    "[from #{name}] #{payload}"
  end

  defp generate_session_id do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
    uuid_bytes = <<a::48, 4::4, b::12, 2::2, c::62>>
    Base.encode16(uuid_bytes, case: :lower) |> format_uuid()
  end

  defp format_uuid(hex) do
    [
      String.slice(hex, 0, 8),
      String.slice(hex, 8, 4),
      String.slice(hex, 12, 4),
      String.slice(hex, 16, 4),
      String.slice(hex, 20, 12)
    ]
    |> Enum.join("-")
  end

  @impl true
  def handle_cast({:tell, message}, state) do
    state = maybe_respawn_claude(state)
    tell_impl(state, message)
  end

  defp tell_impl(state, message) do
    routes = detect_routes(message)
    ref = make_ref()
    new_state = store_tell_immediate(state, message, ref, routes)
    process_tell(new_state, message, ref, routes)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:store_tell, ref, message, response}, state) do
    new_state = complete_tell_entry(state, ref, message, response)
    routes = detect_routes(response)
    process_tell_response(state, response, routes)
    {:noreply, new_state}
  end

  defp complete_tell_entry(state, ref, message, response) do
    new_messages = replace_tell(state.messages, ref, message, response)
    delete_tell_entry(state, message, ref)
    store_tell_entry(state, message, response)
    %{state | messages: new_messages}
  end

  defp delete_tell_entry(state, message, ref) do
    state.store_module.delete_message(
      state.name,
      {"tell", message, "", %{ref: ref}}
    )
  end

  defp store_tell_entry(state, message, response) do
    state.store_module.store_message(
      state.name,
      {"tell", message, response, %{}}
    )
  end

  @impl true
  def handle_cast({:complete_ask, from, message, response, ref}, state) do
    new_state = finalize_ask(state, from, ref, message, response)
    {:noreply, new_state}
  end

  defp finalize_ask(state, from, ref, message, response) do
    delete_ask_entry(state, message, ref)
    store_ask_entry(state, {"ask", message, response, %{}})
    safe_reply(from, response)
    finalize_ask_state(state, from, ref, message, response)
  end

  defp finalize_ask_state(state, from, ref, message, response) do
    new_messages = replace_ask(state.messages, ref, message, response)
    new_pending = List.delete(state.pending_calls, from)
    %{state | messages: new_messages, pending_calls: new_pending}
  end

  defp delete_ask_entry(state, message, ref) do
    state.store_module.delete_message(
      state.name,
      {"ask", message, "", %{ref: ref}}
    )
  end

  defp store_ask_entry(state, entry) do
    state.store_module.store_message(state.name, entry)
  end

  @impl true
  def handle_cast({:cast_store_relay, message, response}, state) do
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry)
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  @impl true
  def handle_cast({:tell_ask, target, message}, state) do
    response = process_tell_ask(state, target, message)
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry)
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  defp process_tell(state, message, ref, []) do
    spawn_tell_task(state, message, ref)
  end

  defp process_tell(state, message, _ref, routes) do
    route_all_tells(state, message, routes)
  end

  defp spawn_tell_task(state, message, ref) do
    server_pid = self()

    state.task_module.start(fn ->
      process_tell_task(state, message, ref, server_pid)
    end)
  end

  defp process_tell_task(state, message, ref, server_pid) do
    response = ask_claude(state.claude_pid, message)
    GenServer.cast(server_pid, {:store_tell, ref, message, response})
  end

  defp route_all_tells(state, message, routes) do
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
    GenServer.cast(via_tuple(target), {:cast_store_relay, relay_payload, ""})
    cast_store_relay(state.name, message, "-> #{target}")
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
    route_if_alive(state, target, fn ->
      El.Session.tell(target, envelope(state.name, payload))
      cast_store_relay(state.name, response, "-> #{target}")
    end)
  end

  defp process_tell_ask(state, target, message) do
    route_if_alive(state, target, fn ->
      state.task_module.start(fn ->
        El.ask(target, envelope(state.name, message))
      end)
    end)
  end

  defp route_if_alive(state, target, on_alive) do
    do_route(target, on_alive, state.alive_fn.(target))
  end

  defp do_route(target, on_alive, true) do
    on_alive.()
    "-> #{target}"
  end

  defp do_route(target, _on_alive, false) do
    "#{target} is not running"
  end

  defp cast_store_relay(sender_name, message, response) do
    pid = via_tuple(sender_name)
    GenServer.cast(pid, {:cast_store_relay, message, response})
  end

  @impl true
  def handle_call({:ask, message}, from, state) do
    state = maybe_respawn_claude(state)
    {ref, ask_state} = prepare_ask(state, from, message)
    spawn_ask(ask_state, from, message, detect_routes(message), ref)
    {:noreply, ask_state}
  end

  defp prepare_ask(state, from, message) do
    valid_routes = filter_self_routes(detect_routes(message), state)
    new_state = %{state | pending_calls: [from | state.pending_calls]}
    store_ask_immediate(new_state, message, valid_routes)
  end

  defp filter_self_routes(routes, state) do
    Enum.filter(routes, fn {target, _} -> target != state.name end)
  end

  @impl true
  def handle_call(:log, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_call({:log, :all}, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_call({:log, count}, _from, state) do
    {:reply, Enum.take(state.messages, -count), state}
  end

  @impl true
  def handle_call({:ask_tell, target, message}, _from, state) do
    response = process_ask_tell(state, target, message)
    entry = build_relay_entry(message, response, state)
    {:reply, response, store_relay_entry(state, entry)}
  end

  defp build_relay_entry(message, response, state) do
    {"relay", message, response, %{from: state.name}}
  end

  defp store_relay_entry(state, entry) do
    state.store_module.store_message(state.name, entry)
    %{state | messages: state.messages ++ [entry]}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    stop_claude(state.claude_pid)
    new_state = reset_session(state)
    {:reply, :ok, new_state}
  end

  defp reset_session(state) do
    state
    |> clear_messages()
    |> start_new_session()
  end

  defp clear_messages(state) do
    state.store_module.delete_session_messages(state.name)
    %{state | messages: []}
  end

  defp start_new_session(state) do
    session_id = generate_session_id()
    opts = Keyword.put(state.opts, :session_id, session_id)
    pid = safe_start_claude(state.claude_module, opts)
    %{state | claude_pid: pid, claude_opts: opts, session_id: session_id}
  end

  defp stop_claude(pid) when is_pid(pid) do
    GenServer.stop(pid)
  end

  defp stop_claude(_), do: :ok

  defp spawn_ask(state, from, message, valid_routes, ref) do
    server_pid = self()

    state.task_module.start(fn ->
      spawn_ask_task(state, from, message, valid_routes, ref, server_pid)
    end)
  end

  defp spawn_ask_task(state, from, message, valid_routes, ref, server_pid) do
    response = protected_ask_work(state, message, valid_routes)
    GenServer.cast(server_pid, {:complete_ask, from, message, response, ref})
  end

  defp protected_ask_work(state, message, routes) do
    do_ask_work(state, message, routes)
  rescue
    _ -> "(error)"
  catch
    :exit, _ -> "(error)"
    _, _ -> "(error)"
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
    route_if_alive(state, target, fn ->
      relay_msg = envelope(state.name, payload)
      GenServer.cast(via_tuple(target), {:cast_store_relay, relay_msg, ""})
      cast_store_relay(state.name, message, "-> #{target}")
    end)
  end

  defp process_ask_tell(state, target, message) do
    route_if_alive(state, target, fn ->
      El.tell(target, envelope(state.name, message))
    end)
  end

  @impl true
  def handle_info({:EXIT, pid, :normal}, %{claude_pid: pid} = state) do
    clear_pending_calls(state.pending_calls)
    {:noreply, %{state | claude_pid: nil, pending_calls: []}}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{claude_pid: pid} = state) do
    {:noreply, handle_claude_crash(state, reason)}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp clear_pending_calls(pending) do
    Enum.each(pending, &safe_reply(&1, "(error)"))
  end

  defp handle_claude_crash(state, reason) do
    log_claude_death(state.name, reason)
    entry = crash_entry(reason)
    store_crash(state, entry)
    crash_state(state, entry)
  end

  defp crash_entry(reason), do: {"crash", "session died", inspect(reason), %{}}

  defp store_crash(state, entry) do
    state.store_module.store_message(state.name, entry)
  end

  defp crash_state(state, entry) do
    clear_pending_calls(state.pending_calls)
    %{state | claude_pid: nil, pending_calls: [], messages: state.messages ++ [entry]}
  end

  @impl true
  def terminate(:normal, _state), do: :ok

  @impl true
  def terminate(:shutdown, _state), do: :ok

  @impl true
  def terminate({:shutdown, _}, _state), do: :ok

  defp log_claude_death(name, reason) do
    msg = "Session #{name} - Claude process died: #{inspect(reason)}"
    Logger.error(msg)
  end

  @impl true
  def terminate(reason, state) do
    entry = {"crash", "Session crashed", inspect(reason), %{}}
    state.store_module.store_message(state.name, entry)
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
    protected_stream(claude_pid, message)
  end

  defp protected_stream(claude_pid, message) do
    safe_stream_claude(claude_pid, message)
  rescue
    _ -> "(ClaudeCode unavailable)"
  catch
    :exit, _ -> "(ClaudeCode unavailable)"
    _, _ -> "(ClaudeCode unavailable)"
  end

  defp safe_stream_claude(claude_pid, message) do
    stream_to_result(claude_pid, message) || ""
  end

  defp stream_to_result(claude_pid, message) do
    claude_pid
    |> El.ClaudeCode.stream(message)
    |> Enum.to_list()
    |> Enum.find_value(&extract_result/1)
  end

  defp extract_result(%ClaudeCode.Message.ResultMessage{result: result}) do
    result
  end

  defp extract_result(_), do: nil

  defp store_ask_immediate(state, message, []) do
    ref = make_ref()
    entry = {"ask", message, "", %{ref: ref}}
    state.store_module.store_message(state.name, entry)
    new_state = %{state | messages: state.messages ++ [entry]}
    {ref, new_state}
  end

  defp store_ask_immediate(state, _message, _routes) do
    ref = make_ref()
    {ref, state}
  end

  defp store_tell_immediate(state, message, ref, []) do
    entry = {"tell", message, "", %{ref: ref}}
    state.store_module.store_message(state.name, entry)
    %{state | messages: state.messages ++ [entry]}
  end

  defp store_tell_immediate(state, _message, _ref, _routes), do: state

  defp replace_tell(messages, ref, message, response) do
    split_and_complete(messages, ref, "tell", message, response)
  end

  defp replace_ask(messages, ref, message, response) do
    split_and_complete(messages, ref, "ask", message, response)
  end

  defp split_and_complete(messages, ref, type, message, response) do
    messages
    |> Enum.split_while(&match_pending_entry(&1, type, ref))
    |> complete_entry(type, message, response)
  end

  defp match_pending_entry({t, _, "", %{ref: r}}, type, ref) do
    r != ref or t != type
  end

  defp match_pending_entry(_, _, _), do: true

  defp complete_entry({before, [{_, _, _, _} | rest]}, type, message, response) do
    entry = {type, message, response, %{}}
    before ++ [entry | rest]
  end

  defp complete_entry({messages, []}, type, message, response) do
    messages ++ [{type, message, response, %{}}]
  end

  defp via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end
end
