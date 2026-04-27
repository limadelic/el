defmodule El.Session.Crash do
  require Logger

  alias El.Session.Claude

  def clear_pending_calls(pending) do
    Enum.each(pending, &Claude.safe_reply(&1, "(error)"))
  end

  def handle_claude_crash(state, reason) do
    log_claude_death(state.name, reason)
    entry = crash_entry(reason)
    store_crash(state, entry)
    crash_state(state, entry)
  end

  defp crash_entry(reason) do
    {"crash", "session died", inspect(reason), %{}}
  end

  defp store_crash(state, entry) do
    state.store_module.store_message(state.name, entry)
  end

  defp crash_state(state, entry) do
    clear_pending_calls(state.pending_calls)
    new_messages = state.messages ++ [entry]
    %{state | claude_pid: nil, pending_calls: [], messages: new_messages}
  end

  defp log_claude_death(name, reason) do
    msg = "Session #{name} - Claude process died: #{inspect(reason)}"
    Logger.error(msg)
  end
end
