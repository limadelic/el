defmodule El.ClaudePort do
  use GenServer

  require Logger

  alias ClaudeCode.CLI.Command
  alias ClaudeCode.CLI.Input
  alias ClaudeCode.Adapter.Port.Resolver
  alias ClaudeCode.Adapter.Port.Installer
  alias El.ClaudePort.Parser

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
    apply_continue_result(open_port(state), state)
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
    safe_close_port(port, port_module)
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

  defp safe_close_port(nil, _port_module), do: :ok
  defp safe_close_port(port, port_module), do: try_close(port_module.info(port), port, port_module)

  defp try_close(nil, _port, _port_module), do: :ok
  defp try_close(_info, port, port_module), do: close_with_rescue(port, port_module)

  defp close_with_rescue(port, port_module) do
    port_module.close(port)
  rescue
    ArgumentError -> :ok
  end

  defp ensure_connected(%{port: nil} = state) do
    apply_ensure_result(open_port(state), state)
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

  defp open_port(state) do
    apply_resolved(resolve_cli_and_args(state.cli_path, state.opts, state.resume_id), state)
  end

  defp apply_resolved({:error, reason}, _state), do: {:error, reason}
  defp apply_resolved({:ok, {executable, args}}, state) do
    find_and_spawn(:os.find_executable(String.to_charlist(executable)), executable, args, state)
  end

  defp find_and_spawn(false, executable, _args, _state) do
    {:error, "CLI executable not found: #{executable}"}
  end
  defp find_and_spawn(exe_path, _executable, args, state) do
    spawn_port(exe_path, args, state.cwd, state.port_module)
  end

  defp spawn_port(exe_path, args, cwd, port_module) do
    env = System.get_env() |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
    port_opts = [
      {:args, args},
      {:cd, String.to_charlist(cwd)},
      {:env, env},
      :binary,
      :exit_status,
      :stderr_to_stdout
    ]

    port_module.open({:spawn_executable, exe_path}, port_opts)
  end

  defp resolve_cli_and_args(_cli_path, opts, resume_id) do
    streaming_opts = Keyword.put(opts, :input_format, :stream_json)
    apply_find_binary(Resolver.find_binary(streaming_opts), streaming_opts, resume_id)
  end

  defp apply_find_binary({:ok, executable}, streaming_opts, resume_id) do
    args = Command.build_args("", streaming_opts, resume_id)
    {:ok, {executable, List.delete_at(args, -1)}}
  end

  defp apply_find_binary({:error, :not_found}, _streaming_opts, _resume_id) do
    {:error, {:cli_not_found, Installer.cli_not_found_message()}}
  end

  defp apply_find_binary({:error, reason}, _streaming_opts, _resume_id) do
    {:error, {:cli_resolution_failed, reason}}
  end

end
