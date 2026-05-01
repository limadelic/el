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

  def stream(pid, message) do
    GenServer.call(pid, {:stream, message})
  end

  @impl GenServer
  def init(opts) do
    cli_path = Application.get_env(:claude_code, :cli_path, :global)
    session_id = Keyword.get(opts, :session_id)
    resume_id = Keyword.get(opts, :resume)
    cwd = Keyword.get(opts, :cwd) || File.cwd!()

    state = %{
      port: nil,
      buffer: "",
      session_id: session_id,
      resume_id: resume_id,
      cwd: cwd,
      cli_path: cli_path,
      opts: opts,
      current_request_id: nil,
      responses: []
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state) do
    case open_port(state) do
      {:ok, port} ->
        {:noreply, %{state | port: port, buffer: ""}}

      {:error, reason} ->
        Logger.error("Failed to open Claude port: #{inspect(reason)}")
        {:noreply, %{state | port: nil}}
    end
  end

  @impl GenServer
  def handle_call({:ask, message}, _from, state) do
    case ensure_connected(state) do
      {:ok, connected_state} ->
        result = do_ask(connected_state, message)
        {:reply, result, connected_state}

      {:error, _reason} ->
        {:reply, {"(unavailable)", nil, nil}, state}
    end
  end

  def handle_call({:stream, message}, _from, state) do
    case ensure_connected(state) do
      {:ok, connected_state} ->
        stream = build_stream(connected_state, message)
        {:reply, stream, connected_state}

      {:error, _reason} ->
        {:reply, [], state}
    end
  end

  @impl GenServer
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    new_buffer = state.buffer <> data
    {:noreply, %{state | buffer: new_buffer}}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.debug("Claude CLI exited with status #{status}")
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
  def terminate(_reason, state) do
    if state.port && Port.info(state.port) do
      Port.close(state.port)
    end
    :ok
  rescue
    ArgumentError -> :ok
  end

  defp ensure_connected(%{port: nil} = state) do
    case open_port(state) do
      {:ok, port} -> {:ok, %{state | port: port, buffer: ""}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_connected(state), do: {:ok, state}

  defp open_port(state) do
    resume_id = state.resume_id
    cli_path = state.cli_path
    cwd = state.cwd
    opts = state.opts

    case resolve_cli_and_args(cli_path, opts, resume_id) do
      {:ok, {executable, args}} ->
        exe_path = executable |> String.to_charlist() |> :os.find_executable()

        if !exe_path do
          {:error, "CLI executable not found: #{executable}"}
        else
          port_opts = [
            {:args, args},
            {:cd, String.to_charlist(cwd)},
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

      {:error, reason} ->
        {:error, reason}
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

  defp do_ask(state, message) do
    session_id = state.session_id
    port = state.port

    ndjson = Input.user_message(message, session_id || "default")
    Port.command(port, ndjson <> "\n")

    events = collect_events(state, [])
    {result, model, sid} = extract_from_events(events)

    {
      nil_to_empty(result),
      model,
      sid || session_id
    }
  end

  defp build_stream(state, message) do
    Stream.unfold(state, fn current_state ->
      session_id = current_state.session_id
      port = current_state.port

      ndjson = Input.user_message(message, session_id || "default")
      Port.command(port, ndjson <> "\n")

      case read_one_event(current_state) do
        {:ok, event, new_state} ->
          {event, new_state}

        :eof ->
          nil
      end
    end)
  end

  defp collect_events(state, acc) do
    case read_one_event(state) do
      {:ok, event, new_state} ->
        if is_result_message(event) do
          Enum.reverse([event | acc])
        else
          collect_events(new_state, [event | acc])
        end

      :eof ->
        Enum.reverse(acc)
    end
  end

  defp read_one_event(state) do
    case extract_one_line(state.buffer) do
      {nil, _} ->
        case read_from_port_timeout(state.port, 5000) do
          {:data, data} ->
            new_buffer = state.buffer <> data
            read_one_event(%{state | buffer: new_buffer})

          :timeout ->
            :eof

          :error ->
            :eof
        end

      {line, remaining} ->
        case Jason.decode(line) do
          {:ok, json} ->
            {:ok, Parser.normalize_keys(json), %{state | buffer: remaining}}

          {:error, _} ->
            read_one_event(%{state | buffer: remaining})
        end
    end
  end

  defp extract_one_line(buffer) do
    case String.split(buffer, "\n", parts: 2) do
      [line, rest] -> {line, rest}
      [_incomplete] -> {nil, buffer}
      [] -> {nil, ""}
    end
  end

  defp read_from_port_timeout(port, timeout) do
    receive do
      {^port, {:data, data}} -> {:data, data}
      {^port, :eof} -> :error
      {^port, {:exit_status, _}} -> :error
    after
      timeout -> :timeout
    end
  end

  defp is_result_message(%{"type" => "result"}), do: true
  defp is_result_message(_), do: false

  defp extract_from_events(events) do
    result = Enum.find_value(events, &extract_result/1)
    model = Enum.find_value(events, &extract_model/1)
    session_id = Enum.find_value(events, &extract_session_id/1)
    {result, model, session_id}
  end

  defp extract_result(%{"type" => "result", "result" => result}), do: result
  defp extract_result(_), do: nil

  defp extract_model(%{"type" => "system", "message_type" => "init", "model" => model}), do: model
  defp extract_model(_), do: nil

  defp extract_session_id(%{"type" => "system", "message_type" => "init", "session_id" => session_id}), do: session_id
  defp extract_session_id(_), do: nil

  defp nil_to_empty(nil), do: ""
  defp nil_to_empty(result), do: result
end
