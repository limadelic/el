defmodule El.ClaudePort do
  use GenServer

  require Logger

  alias ClaudeCode.CLI.Input
  alias El.ClaudePort.Parser
  alias El.ClaudePort.Connection
  alias El.ClaudePort.Buffer

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
    Map.merge(runtime_state(), opts_state(opts))
  end

  defp runtime_state do
    %{port: nil, buffer: "", current_request_id: nil, responses: []}
  end

  defp opts_state(opts) do
    Map.merge(opts_ids(opts), opts_env(opts))
  end

  defp opts_ids(opts) do
    %{
      session_id: Keyword.get(opts, :session_id),
      resume_id: Keyword.get(opts, :resume),
      opts: opts
    }
  end

  defp opts_env(opts) do
    %{
      cwd: cwd(Keyword.get(opts, :cwd)),
      cli_path: Keyword.get(opts, :cli_path, :global),
      port_module: Keyword.get(opts, :port_module, El.PortImpl)
    }
  end

  defp cwd(nil), do: File.cwd!()
  defp cwd(path), do: path

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
    send_message(connected_state, message)
    {:noreply, %{connected_state | current_request_id: from}}
  end

  defp dispatch_ask({:error, reason}, _message, _from, state) do
    Logger.error("ClaudePort ensure_connected failed: #{inspect(reason)}")
    {:reply, {"(unavailable)", nil, nil}, state}
  end

  defp send_message(state, message) do
    session_id = session_id_or_default(state.session_id)
    ndjson = Input.user_message(message, session_id)
    state.port_module.command(state.port, ndjson <> "\n")
  end

  defp session_id_or_default(nil), do: "default"
  defp session_id_or_default(id), do: id

  @impl GenServer
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    case Buffer.process(data, state) do
      {:noreply, new_state} ->
        {:noreply, new_state}

      {:reply, from, result, new_state} ->
        GenServer.reply(from, result)
        {:noreply, new_state}
    end
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
