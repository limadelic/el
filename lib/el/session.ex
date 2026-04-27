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
    claude_module = Keyword.get(opts, :claude_module, El.ClaudeCode)
    task_module = Keyword.get(opts, :task_module, Task)
    alive_fn = Keyword.get(opts, :alive_fn, &El.Session.alive?/1)
    registry_module = Keyword.get(opts, :registry_module, Registry)
    store_module = Keyword.get(opts, :store_module, El.Application)

    {session_id, opts_without_resume} =
      extract_resume_or_generate_session_id(opts)

    claude_opts = Keyword.put(opts_without_resume, :session_id, session_id)

    {:ok,
     %{
       name: name,
       claude_pid: nil,
       session_id: session_id,
       messages: [],
       pending_calls: [],
       claude_module: claude_module,
       task_module: task_module,
       alive_fn: alive_fn,
       registry_module: registry_module,
       store_module: store_module,
       opts: opts,
       claude_opts: claude_opts
     }, {:continue, :start_claude}}
  end

  @impl true
  def handle_continue(:start_claude, state) do
    messages = state.store_module.load_messages(state.name)
    claude_pid = safe_start_claude(state.claude_module, state.claude_opts)
    {:noreply, %{state | claude_pid: claude_pid, messages: messages}}
  end

  defp maybe_respawn_claude(
         %{
           claude_pid: nil,
           opts: opts,
           session_id: session_id,
           claude_module: claude_module
         } = state
       ) do
    opts_with_resume =
      opts
      |> Keyword.put(:session_id, session_id)
      |> Keyword.put(:resume, session_id)

    pid = safe_start_claude(claude_module, opts_with_resume)
    %{state | claude_pid: pid}
  end

  defp maybe_respawn_claude(%{claude_pid: pid} = state) when is_pid(pid) do
    if Process.alive?(pid) do
      state
    else
      maybe_respawn_claude(%{state | claude_pid: nil})
    end
  end

  defp safe_start_claude(claude_module, opts) do
    case claude_module.start_link(opts) do
      {:ok, pid} -> pid
      _ -> nil
    end
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  defp envelope(name, payload) do
    "[from #{name}] #{payload}"
  end

  defp extract_resume_or_generate_session_id(opts) do
    case Keyword.pop(opts, :resume) do
      {nil, remaining_opts} ->
        {generate_session_id(), remaining_opts}

      {session_id, remaining_opts} ->
        {session_id, remaining_opts}
    end
  end

  defp generate_session_id do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
    uuid_bytes = <<a::48, 4::4, b::12, 2::2, c::62>>
    hex = Base.encode16(uuid_bytes, case: :lower)
    format_uuid(hex)
  end

  defp format_uuid(hex) do
    s0 = String.slice(hex, 0, 8)
    s1 = String.slice(hex, 8, 4)
    s2 = String.slice(hex, 12, 4)
    s3 = String.slice(hex, 16, 4)
    s4 = String.slice(hex, 20, 12)
    "#{s0}-#{s1}-#{s2}-#{s3}-#{s4}"
  end

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
    delete_tell_entry(state, message, ref)
    store_tell_entry(state, message, response)
    routes = detect_routes(response)
    process_tell_response(state, response, routes)
    {:noreply, new_state}
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
    entry = {"ask", message, response, %{}}
    new_messages = replace_ask(state.messages, ref, message, response)
    delete_ask_entry(state, message, ref)
    store_ask_entry(state, entry)
    safe_reply(from, response)
    new_pending = List.delete(state.pending_calls, from)
    {:noreply, %{state | messages: new_messages, pending_calls: new_pending}}
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

    new_state = %{state | messages: state.messages ++ [entry]}

    {:noreply, new_state}
  end

  defp process_tell(state, message, ref, []) do
    server_pid = self()

    state.task_module.start(fn ->
      response = ask_claude(state.claude_pid, message)
      GenServer.cast(server_pid, {:store_tell, ref, message, response})
    end)
  end

  defp process_tell(state, message, _ref, routes) do
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
      GenServer.cast(
        via_tuple(target),
        {:cast_store_relay, envelope(state.name, payload), ""}
      )

      cast_store_relay(state.name, message, "-> #{target}")
    end)
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
    routes = detect_routes(message)

    valid_routes =
      Enum.filter(routes, fn {target, _} -> target != state.name end)

    new_state = %{state | pending_calls: [from | state.pending_calls]}

    {ref, state_with_pending} =
      store_ask_immediate(new_state, message, valid_routes)

    spawn_ask(state_with_pending, from, message, valid_routes, ref)
    {:noreply, state_with_pending}
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
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry)

    new_state = %{state | messages: state.messages ++ [entry]}

    {:reply, response, new_state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    stop_claude(state.claude_pid)

    new_session_id = generate_session_id()
    claude_opts = Keyword.put(state.opts, :session_id, new_session_id)
    new_claude_pid = safe_start_claude(state.claude_module, claude_opts)

    state.store_module.delete_session_messages(state.name)

    new_state = %{
      state
      | claude_pid: new_claude_pid,
        claude_opts: claude_opts,
        session_id: new_session_id,
        messages: []
    }

    {:reply, :ok, new_state}
  end

  defp stop_claude(pid) when is_pid(pid) do
    GenServer.stop(pid)
  end

  defp stop_claude(_), do: :ok

  defp spawn_ask(state, from, message, valid_routes, ref) do
    server_pid = self()

    state.task_module.start(fn ->
      response =
        try do
          do_ask_work(state, message, valid_routes)
        rescue
          _ -> "(error)"
        catch
          :exit, _ -> "(error)"
          _, _ -> "(error)"
        end

      GenServer.cast(server_pid, {:complete_ask, from, message, response, ref})
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
    Enum.each(state.pending_calls, fn from ->
      safe_reply(from, "(error)")
    end)

    {:noreply, %{state | claude_pid: nil, pending_calls: []}}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{claude_pid: pid} = state) do
    log_claude_death(state.name, reason)
    entry = {"crash", "session died", inspect(reason), %{}}
    state.store_module.store_message(state.name, entry)

    Enum.each(state.pending_calls, fn from ->
      safe_reply(from, "(error)")
    end)

    new_state = %{
      state
      | claude_pid: nil,
        pending_calls: [],
        messages: state.messages ++ [entry]
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
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
    state.store_module.store_message(
      state.name,
      {"crash", "Session crashed", inspect(reason), %{}}
    )

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
    |> Enum.to_list()
    |> Enum.find_value(fn
      %ClaudeCode.Message.ResultMessage{result: result} -> result
      _ -> nil
    end) || ""
  end

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

  defp replace_ask(messages, ref, message, response) do
    messages
    |> Enum.split_while(fn
      {"ask", _, "", %{ref: ^ref}} -> false
      _ -> true
    end)
    |> complete_ask(message, response)
  end

  defp complete_ask({before, [{_, _, _, _} | rest]}, message, response) do
    before ++ [{"ask", message, response, %{}} | rest]
  end

  defp complete_ask({messages, []}, message, response) do
    messages ++ [{"ask", message, response, %{}}]
  end

  defp via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end
end
