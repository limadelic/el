defmodule El.Session do
  use GenServer

  require Logger

  alias El.Session.Terminator
  alias El.Session.LogHandler
  alias El.Session.InfoHandler
  alias El.Session.CastHandler
  alias El.Session.CallHandler

  @impl true
  def init({name, opts}) do
    Process.flag(:trap_exit, true)
    {session_id, rest} = El.Session.Id.extract_resume_or_id(opts)
    cwd = file_system(opts).cwd()
    {:ok, state_module(opts).build(name, opts, rest, session_id, cwd), {:continue, :start_claude}}
  end

  defp file_system(opts) do
    Keyword.get(opts, :file_system, El.Infra.FileSystem)
  end

  defp state_module(opts) do
    Keyword.get(opts, :state_module, El.Session.State)
  end

  @impl true
  def handle_continue(:start_claude, state) do
    state.bootstrap_module.handle_continue(state)
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
