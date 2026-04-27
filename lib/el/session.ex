defmodule El.Session do
  use GenServer

  require Logger

  alias El.Session.Registry
  alias El.Session.Claude
  alias El.Session.Crash
  alias El.Session.Router
  alias El.Session.Store
  alias El.Session.Tell

  def start_link({name, session_opts}) do
    opts = [name: Registry.via_tuple(name)]
    GenServer.start_link(__MODULE__, {name, session_opts}, opts)
  end

  def tell(name, message) do
    GenServer.cast(Registry.via_tuple(name), {:tell, message})
  end

  def ask(name, message) do
    GenServer.call(Registry.via_tuple(name), {:ask, message}, :infinity)
  end

  def log(name) do
    GenServer.call(Registry.via_tuple(name), :log, :infinity)
  end

  def log(name, count) do
    GenServer.call(Registry.via_tuple(name), {:log, count}, :infinity)
  end

  def clear(name) do
    GenServer.call(Registry.via_tuple(name), :clear)
  end

  def tell_ask(name, target, message) do
    GenServer.cast(Registry.via_tuple(name), {:tell_ask, target, message})
  end

  def ask_tell(name, target, message) do
    GenServer.call(Registry.via_tuple(name), {:ask_tell, target, message}, :infinity)
  end

  def detect_routes(text) do
    Router.detect_routes(text)
  end

  def alive?(name) do
    Registry.alive?(name)
  end

  @impl true
  def init({name, opts}) do
    Process.flag(:trap_exit, true)
    {session_id, rest} = El.Session.Id.extract_resume_or_id(opts)
    {:ok, build_state(name, opts, rest, session_id), {:continue, :start_claude}}
  end

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
    claude_pid = Claude.start(state.claude_module, state.claude_opts)
    {:noreply, %{state | claude_pid: claude_pid, messages: messages}}
  end

  @impl true
  def handle_cast({:tell, message}, state) do
    state = Claude.maybe_respawn_claude(state)
    Tell.tell_impl(state, message)
  end

  @impl true
  def handle_cast({:store_tell, ref, message, response}, state) do
    new_state = Store.complete_tell_entry(state, ref, message, response)
    routes = Router.detect_routes(response)
    Router.process_tell_response(state, response, routes)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:complete_ask, from, message, response, ref}, state) do
    new_state = finalize_ask(state, from, ref, message, response)
    {:noreply, new_state}
  end

  defp finalize_ask(state, from, ref, message, response) do
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

  @impl true
  def handle_cast({:cast_store_relay, message, response}, state) do
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry)
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  @impl true
  def handle_cast({:tell_ask, target, message}, state) do
    response = Router.process_tell_ask(state, target, message)
    entry = {"relay", message, response, %{from: state.name}}
    state.store_module.store_message(state.name, entry)
    {:noreply, %{state | messages: state.messages ++ [entry]}}
  end

  @impl true
  def handle_call({:ask, message}, from, state) do
    state = Claude.maybe_respawn_claude(state)
    {ref, ask_state} = prepare_ask(state, from, message)
    spawn_ask(ask_state, from, message, Router.detect_routes(message), ref)
    {:noreply, ask_state}
  end

  defp prepare_ask(state, from, message) do
    valid_routes = Router.filter_self_routes(Router.detect_routes(message), state)
    new_state = %{state | pending_calls: [from | state.pending_calls]}
    Store.store_ask_immediate(new_state, message, valid_routes)
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
    response = Router.process_ask_tell(state, target, message)
    entry = Store.build_relay_entry(message, response, state)
    {:reply, response, Store.store_relay_entry(state, entry)}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    Claude.stop_claude(state.claude_pid)
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
    session_id = El.Session.Id.generate_session_id()
    opts = Keyword.put(state.opts, :session_id, session_id)
    pid = Claude.start(state.claude_module, opts)
    %{state | claude_pid: pid, claude_opts: opts, session_id: session_id}
  end

  defp spawn_ask(state, from, message, valid_routes, ref) do
    server_pid = self()

    state.task_module.start(fn ->
      spawn_ask_task(state, from, message, valid_routes, ref, server_pid)
    end)
  end

  defp spawn_ask_task(state, from, message, valid_routes, ref, server_pid) do
    response = Claude.ask_work(state.claude_pid, message, valid_routes)
    GenServer.cast(server_pid, {:complete_ask, from, message, response, ref})
  end

  @impl true
  def handle_info({:EXIT, pid, :normal}, %{claude_pid: pid} = state) do
    Crash.clear_pending_calls(state.pending_calls)
    {:noreply, %{state | claude_pid: nil, pending_calls: []}}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{claude_pid: pid} = state) do
    {:noreply, Crash.handle_claude_crash(state, reason)}
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

  @impl true
  def terminate(reason, state) do
    entry = {"crash", "Session crashed", inspect(reason), %{}}
    state.store_module.store_message(state.name, entry)
    :ok
  end
end
