defmodule El.Session.Claude do
  require Logger

  def start(claude_module, opts) do
    start_claude_safe(claude_module.start_link(opts))
  end

  defp start_claude_safe({:ok, pid}), do: pid
  defp start_claude_safe(_), do: nil

  def respawn(nil, claude_module, opts) do
    start(claude_module, opts)
  end

  def respawn(pid, _claude_module, _opts) when is_pid(pid) do
    check_alive(Process.alive?(pid), pid)
  end

  defp check_alive(true, pid), do: pid
  defp check_alive(false, _pid), do: nil

  def resume_options(opts, session_id) do
    opts
    |> Keyword.put(:session_id, session_id)
    |> Keyword.put(:resume, session_id)
  end

  def ask(nil, _message) do
    "(ClaudeCode unavailable)"
  end

  def ask(pid, message) do
    stream(pid, message)
  end

  defp stream(pid, message) do
    safe_stream(pid, message)
  end

  defp safe_stream(pid, message) do
    pid |> stream_to_result(message) |> nil_to_empty()
  end

  defp nil_to_empty(nil), do: ""
  defp nil_to_empty(result), do: result

  defp stream_to_result(pid, message) do
    pid
    |> El.ClaudeCode.stream(message)
    |> Enum.to_list()
    |> Enum.find_value(&extract_result/1)
  end

  defp extract_result(%ClaudeCode.Message.ResultMessage{result: result}) do
    result
  end

  defp extract_result(_), do: nil

  def ask_work(pid, message, _routes) do
    ask(pid, message)
  end

  def maybe_respawn_claude(%{claude_pid: nil} = state) do
    opts = resume_options(state.opts, state.session_id)
    pid = start(state.claude_module, opts)
    %{state | claude_pid: pid}
  end

  def maybe_respawn_claude(%{claude_pid: pid} = state) when is_pid(pid) do
    check_claude_alive(Process.alive?(pid), state)
  end

  defp check_claude_alive(true, state), do: state

  defp check_claude_alive(false, state) do
    maybe_respawn_claude(%{state | claude_pid: nil})
  end

  def stop_claude(pid) when is_pid(pid) do
    GenServer.stop(pid)
  end

  def stop_claude(_), do: :ok

  def clear_pending_calls(pending) do
    Enum.each(pending, &safe_reply(&1, "(error)"))
  end

  def handle_claude_crash(state, reason) do
    log_claude_death(state.name, reason)
    entry = crash_entry(reason)
    store_crash(state, entry)
    crash_state(state, entry)
  end

  defp crash_entry(reason), do: {"crash", "session died", inspect(reason), %{}}

  defp store_crash(state, entry) do
    state.store_module.store_message(state.name, entry)
  end

  defp crash_state(state, entry) do
    clear_pending_calls(state.pending_calls)
    %{state | claude_pid: nil, pending_calls: [], messages: state.messages ++ [entry]}
  end

  defp log_claude_death(name, reason) do
    msg = "Session #{name} - Claude process died: #{inspect(reason)}"
    Logger.error(msg)
  end

  def safe_reply(from, response) do
    spawn(fn -> GenServer.reply(from, response) end)
  end
end
