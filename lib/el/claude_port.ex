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
  def terminate(_reason, %{port: port}) do
    safe_close_port(port)
    :ok
  end

  defp process_chunk(data, state) do
    new_buffer = state.buffer <> data
    new_state = %{state | buffer: new_buffer}

    case state.current_request_id do
      nil ->
        new_state

      from ->
        case try_extract_result(new_state) do
          {:ok, result, remaining_buffer} ->
            GenServer.reply(from, result)
            %{new_state | buffer: remaining_buffer, current_request_id: nil}

          :incomplete ->
            new_state
        end
    end
  end

  defp safe_close_port(port) do
    if port && Port.info(port) do
      Port.close(port)
    end
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

    case resolve_cli_and_args(cli_path, opts, resume_id) do
      {:ok, {executable, args}} ->
        exe_path = executable |> String.to_charlist() |> :os.find_executable()

        if exe_path do
          spawn_port(exe_path, args, cwd)
        else
          {:error, "CLI executable not found: #{executable}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp spawn_port(exe_path, args, cwd) do
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
      port = Port.open({:spawn_executable, exe_path}, port_opts)
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

        if complete? do
          {new_result, new_model, new_sid} = new_acc
          {:complete, new_result, new_model, new_sid}
        else
          process_lines(rest, new_acc, session_id)
        end

      {:error, _reason} ->
        process_lines(rest, acc, session_id)
    end
  end

  defp merge_line(normalized, {result, model, sid}) do
    new_result = if is_result_message(normalized), do: get_result(normalized), else: result
    new_model = if has_model(normalized), do: get_model(normalized), else: model
    new_sid = if has_session_id(normalized), do: get_session_id(normalized), else: sid
    complete? = is_result_message(normalized)

    {{new_result, new_model, new_sid}, complete?}
  end

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
