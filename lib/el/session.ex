defmodule El.Session do
  use GenServer

  require Logger

  alias El.Session.Registry
  alias El.Session.Claude
  alias El.Session.Terminator
  alias El.Session.LogHandler
  alias El.Session.InfoHandler
  alias El.Session.CastHandler
  alias El.Session.CallHandler

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
      alive_fn: Keyword.get(opts, :alive_fn, &El.Session.Api.alive?/1),
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
  def handle_cast(msg, state) do
    CastHandler.handle(msg, state)
  end

  @impl true
  def handle_call({:ask, _} = msg, from, state) do
    CallHandler.handle(msg, from, state)
  end

  @impl true
  def handle_call(:log, _from, state) do
    LogHandler.handle_log(:log, state)
  end

  @impl true
  def handle_call({:log, _} = msg, _from, state) do
    LogHandler.handle_log(msg, state)
  end

  @impl true
  def handle_call({:ask_tell, _, _} = msg, from, state) do
    CallHandler.handle(msg, from, state)
  end

  @impl true
  def handle_call(:clear, from, state) do
    CallHandler.handle(:clear, from, state)
  end

  @impl true
  def handle_info(msg, state) do
    InfoHandler.handle(msg, state)
  end

  @impl true
  def terminate(reason, state) do
    Terminator.handle(reason, state)
  end
end
