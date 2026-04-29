defmodule El.Session.InfoHandler do
  alias El.Session.Crash

  def handle({:EXIT, pid, :normal}, %{claude_pid: pid} = state) do
    Crash.clear_pending_calls(state.pending_calls)
    {:noreply, %{state | claude_pid: nil, pending_calls: []}}
  end

  def handle({:EXIT, pid, reason}, %{claude_pid: pid} = state) do
    {:noreply, Crash.handle_claude_crash(state, reason)}
  end

  def handle(_msg, state) do
    {:noreply, state}
  end
end
