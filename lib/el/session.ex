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

  @defaults %{
    claude_module: El.ClaudeCode,
    task_module: Task,
    alive_fn: &El.Session.Api.alive?/1,
    registry_module: Registry,
    store_module: El.Application
  }
  @base_state_defaults %{
    name: nil,
    claude_pid: nil,
    session_id: nil,
    cwd: nil,
    messages: [],
    pending_calls: [],
    opts: []
  }

  @impl true
  def init({name, opts}) do
    Process.flag(:trap_exit, true)
    {session_id, rest} = El.Session.Id.extract_resume_or_id(opts)
    cwd = file_system(opts).cwd()
    {:ok, build_state(name, opts, rest, session_id, cwd), {:continue, :start_claude}}
  end

  defp build_state(name, opts, rest, session_id, cwd) do
    base_state(name, session_id, cwd, opts)
    |> Map.merge(modules_and_callbacks(opts))
    |> Map.put(:claude_opts, Keyword.put(rest, :session_id, session_id))
  end

  defp base_state(n, s, c, o),
    do: @base_state_defaults |> Map.merge(%{name: n, session_id: s, cwd: c, opts: o})

  defp modules_and_callbacks(o), do: get_opts(o)

  defp get_opts(o), do: @defaults |> Map.merge(Map.new(o))

  defp file_system(opts) do
    Keyword.get(opts, :file_system, Application.get_env(:el, :file_system, El.FileSystemImpl))
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
  def handle_call(:agent, from, state), do: CallHandler.handle(:agent, from, state)

  @impl true
  def handle_call(:info, from, state), do: CallHandler.handle(:info, from, state)

  @impl true
  def handle_info(msg, state) do
    InfoHandler.handle(msg, state)
  end

  @impl true
  def terminate(reason, state) do
    Terminator.handle(reason, state)
  end
end
