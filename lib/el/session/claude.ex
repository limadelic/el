defmodule El.Session.Claude do
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
end
