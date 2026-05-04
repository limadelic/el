defmodule El.ClaudePort do
  use GenServer

  require Logger

  alias ClaudeCode.CLI.Command
  alias ClaudeCode.CLI.Input
  alias ClaudeCode.CLI.Parser
  alias ClaudeCode.Adapter.Port.Resolver
  alias ClaudeCode.Adapter.Port.Installer

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
    case ensure_connected(state) do
      {:ok, connected_state} ->
        Logger.debug("ClaudePort connected, sending message")
        session_id = connected_state.session_id
        port = connected_state.port

        ndjson = Input.user_message(message, session_id || "default")
        Port.command(port, ndjson <> "\n")

        new_state = %{connected_state | current_request_id: from}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("ClaudePort ensure_connected failed: #{inspect(reason)}")
        {:reply, {"(unavailable)", nil, nil}, state}
    end
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
  defp maybe_extract(state), do: dispatch_extraction(try_extract_result(state), state)

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
    resume_id = state.resume_id
    cli_path = state.cli_path
    cwd = state.cwd
    opts = state.opts
    port_module = state.port_module

    case resolve_cli_and_args(cli_path, opts, resume_id) do
      {:ok, {executable, args}} ->
        exe_path = executable |> String.to_charlist() |> :os.find_executable()

        if exe_path do
          spawn_port(exe_path, args, cwd, port_module)
        else
          {:error, "CLI executable not found: #{executable}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
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

    try do
      port = port_module.open({:spawn_executable, exe_path}, port_opts)
      {:ok, port}
    rescue
      e -> {:error, {:port_open_failed, e}}
    end
  end

  defp resolve_cli_and_args(_cli_path, opts, resume_id) do
    streaming_opts = Keyword.put(opts, :input_format, :stream_json)

    case Resolver.find_binary(streaming_opts) do
      {:ok, executable} ->
        args = Command.build_args("", streaming_opts, resume_id)
        {:ok, {executable, List.delete_at(args, -1)}}

      {:error, :not_found} ->
        {:error, {:cli_not_found, Installer.cli_not_found_message()}}

      {:error, reason} ->
        {:error, {:cli_resolution_failed, reason}}
    end
  end

  defp try_extract_result(state) do
    case extract_all_lines(state.buffer, []) do
      {[], _remaining} ->
        :incomplete

      {lines, remaining} ->
        case process_lines(lines, {nil, nil, nil}, state.session_id) do
          {:complete, result, model, sid} ->
            {:ok, {nil_to_empty(result), model, sid || state.session_id}, remaining}

          :incomplete ->
            :incomplete
        end
    end
  end

  defp extract_all_lines(buffer, acc) do
    case extract_one_line(buffer) do
      {nil, _} ->
        {Enum.reverse(acc), buffer}

      {line, remaining} ->
        extract_all_lines(remaining, [line | acc])
    end
  end

  defp process_lines([], _acc, _session_id), do: :incomplete

  defp process_lines([line | rest], acc, session_id) do
    case Jason.decode(line) do
      {:ok, json} ->
        normalized = Parser.normalize_keys(json)
        {new_acc, complete?} = merge_line(normalized, acc)
        emit_or_continue(complete?, new_acc, rest, session_id)

      {:error, _reason} ->
        process_lines(rest, acc, session_id)
    end
  end

  defp emit_or_continue(true, new_acc, _rest, _session_id) do
    {new_result, new_model, new_sid} = new_acc
    {:complete, new_result, new_model, new_sid}
  end

  defp emit_or_continue(false, new_acc, rest, session_id) do
    process_lines(rest, new_acc, session_id)
  end

  defp merge_line(normalized, {result, model, sid}) do
    {
      {
        pick_result(is_result_message(normalized), normalized, result),
        pick_model(has_model(normalized), normalized, model),
        pick_sid(has_session_id(normalized), normalized, sid)
      },
      is_result_message(normalized)
    }
  end

  defp pick_result(true, normalized, _result), do: get_result(normalized)
  defp pick_result(false, _normalized, result), do: result

  defp pick_model(true, normalized, _model), do: get_model(normalized)
  defp pick_model(false, _normalized, model), do: model

  defp pick_sid(true, normalized, _sid), do: get_session_id(normalized)
  defp pick_sid(false, _normalized, sid), do: sid

  defp extract_one_line(buffer) do
    case String.split(buffer, "\n", parts: 2) do
      [line, rest] -> {line, rest}
      [_incomplete] -> {nil, buffer}
      [] -> {nil, ""}
    end
  end

  defp is_result_message(%{"type" => "result"}), do: true
  defp is_result_message(_), do: false

  defp has_model(%{"type" => "system", "subtype" => "init"}), do: true
  defp has_model(_), do: false

  defp has_session_id(%{"type" => "system", "subtype" => "init"}), do: true
  defp has_session_id(_), do: false

  defp get_result(%{"type" => "result", "result" => result}), do: result
  defp get_result(%{"type" => "result"} = event) do
    Logger.debug("ClaudePort found result event but no 'result' key: #{inspect(event)}")
    nil
  end
  defp get_result(_), do: nil

  defp get_model(%{"type" => "system", "subtype" => "init", "model" => model}), do: model
  defp get_model(_), do: nil

  defp get_session_id(%{"type" => "system", "subtype" => "init", "session_id" => session_id}), do: session_id
  defp get_session_id(_), do: nil

  defp nil_to_empty(nil), do: ""
  defp nil_to_empty(result), do: result
end
