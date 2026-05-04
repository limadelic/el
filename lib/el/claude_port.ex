defmodule El.ClaudePort do
  use GenServer

  require Logger

  alias ClaudeCode.CLI.Input
  alias El.ClaudePort.Parser
  alias El.ClaudePort.Connection

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def ask(pid, message) do
    GenServer.call(pid, {:ask, message}, :infinity)
  end

  @impl GenServer
  def init(opts) do
    {:ok, build_state(opts), {:continue, :connect}}
  end

  defp build_state(opts) do
    %{
      port: nil,
      buffer: "",
      session_id: Keyword.get(opts, :session_id),
      resume_id: Keyword.get(opts, :resume),
      cwd: Keyword.get(opts, :cwd) || File.cwd!(),
      cli_path: Application.get_env(:claude_code, :cli_path, :global),
      port_module: Keyword.get(opts, :port_module, El.PortImpl),
      opts: opts,
      current_request_id: nil,
      responses: []
    }
  end

  @impl GenServer
  def handle_continue(:connect, state) do
    apply_continue_result(Connection.open_port(state), state)
  end

  @impl GenServer
  def handle_call({:ask, message}, from, state) do
    dispatch_ask(ensure_connected(state), message, from, state)
  end

  defp dispatch_ask({:ok, connected_state}, message, from, _state) do
    Logger.debug("ClaudePort connected, sending message")
    session_id = connected_state.session_id
    port = connected_state.port
    ndjson = Input.user_message(message, session_id || "default")
    connected_state.port_module.command(port, ndjson <> "\n")
    {:noreply, %{connected_state | current_request_id: from}}
  end

  defp dispatch_ask({:error, reason}, _message, _from, state) do
    Logger.error("ClaudePort ensure_connected failed: #{inspect(reason)}")
    {:reply, {"(unavailable)", nil, nil}, state}
  end

  @impl GenServer
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    {:noreply, process_chunk(data, state)}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.debug("Claude port exited with status: #{status}")
    {:noreply, %{state | port: nil, buffer: ""}}
  end

  def handle_info({:DOWN, _ref, :port, port, reason}, %{port: port} = state) do
    Logger.error("Claude port closed: #{inspect(reason)}")
    {:noreply, %{state | port: nil, buffer: ""}}
  end

  def handle_info({port, :eof}, %{port: port} = state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %{port: nil}), do: :ok
  def terminate(_reason, %{port: port, port_module: port_module}) do
    Connection.safe_close_port(port, port_module)
    :ok
  end

  defp process_chunk(data, state) do
    new_state = %{state | buffer: state.buffer <> data}
    maybe_extract(new_state)
  end

  defp maybe_extract(%{current_request_id: nil} = state), do: state
  defp maybe_extract(state), do: dispatch_extraction(Parser.try_extract_result(state.buffer, state.session_id), state)

  defp dispatch_extraction(:incomplete, state), do: state
  defp dispatch_extraction({:ok, result, remaining_buffer}, state) do
    GenServer.reply(state.current_request_id, result)
    %{state | buffer: remaining_buffer, current_request_id: nil}
  end

  defp ensure_connected(%{port: nil} = state) do
    apply_ensure_result(Connection.open_port(state), state)
  end

  defp ensure_connected(state), do: {:ok, state}

  defp apply_continue_result({:ok, port}, state) do
    {:noreply, %{state | port: port, buffer: ""}}
  end

  defp apply_continue_result({:error, reason}, state) do
    Logger.error("Failed to open Claude port: #{inspect(reason)}")
    {:noreply, %{state | port: nil}}
  end

  defp apply_ensure_result({:ok, port}, state) do
    {:ok, %{state | port: port, buffer: ""}}
  end

  defp apply_ensure_result({:error, reason}, _state) do
    {:error, reason}
  end

end
