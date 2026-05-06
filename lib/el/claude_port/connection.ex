defmodule El.ClaudePort.Connection do
  @behaviour El.Behaviours.ClaudePortConnection

  require Logger

  alias ClaudeCode.CLI.Command
  alias ClaudeCode.CLI.Input
  alias ClaudeCode.Adapter.Port.Resolver
  alias ClaudeCode.Adapter.Port.Installer

  def open_port(state) do
    apply_resolved(resolve_cli_and_args(state.cli_path, state.opts, state.resume_id), state)
  end

  def safe_close_port(nil, _port_module), do: :ok
  def safe_close_port(port, port_module), do: try_close(port_module.info(port), port, port_module)

  def send_message(state, message) do
    session_id = session_id_or_default(state.session_id)
    ndjson = Input.user_message(message, session_id)
    state.port_module.command(state.port, ndjson <> "\n")
  end

  def session_id_or_default(nil), do: "default"
  def session_id_or_default(id), do: id

  def handle_ask(state, message, from) do
    case ensure_connected(state) do
      {:ok, connected_state} ->
        Logger.debug("ClaudePort connected, sending message")
        send_message(connected_state, message)
        {:noreply, %{connected_state | current_request_id: from}}

      {:error, reason} ->
        Logger.error("ClaudePort ensure_connected failed: #{inspect(reason)}")
        {:reply, {"(unavailable)", nil, nil}, state}
    end
  end

  def handle_connect(state) do
    apply_continue_result(open_port(state), state)
  end

  defp try_close(nil, _port, _port_module), do: :ok
  defp try_close(_info, port, port_module), do: close_with_rescue(port, port_module)

  defp close_with_rescue(port, port_module) do
    port_module.close(port)
  rescue
    ArgumentError -> :ok
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
    port_module.open({:spawn_executable, exe_path}, port_opts(args, cwd))
  end

  defp port_opts(args, cwd) do
    named_opts(args, cwd) ++ port_flags()
  end

  defp named_opts(args, cwd) do
    [
      {:args, args},
      {:cd, String.to_charlist(cwd)},
      {:env, env_charlist()}
    ]
  end

  defp port_flags, do: [:binary, :exit_status, :stderr_to_stdout]

  defp env_charlist do
    Enum.map(System.get_env(), &charlist_pair/1)
  end

  defp charlist_pair({k, v}) do
    {String.to_charlist(k), String.to_charlist(v)}
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
end
