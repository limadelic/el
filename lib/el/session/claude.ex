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
    {"(unavailable)", nil, nil}
  end

  def ask(pid, message) do
    {result, model, session_id} = El.ClaudePort.ask(pid, message)
    {nil_to_empty(result), model, session_id}
  end

  defp nil_to_empty(nil), do: ""
  defp nil_to_empty(result), do: result

  def ask_work(pid, message, _routes) do
    {result, model, session_id} = ask(pid, message)
    {result, model, session_id}
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

  def safe_reply(from, response) do
    spawn(fn -> GenServer.reply(from, response) end)
  end
end
