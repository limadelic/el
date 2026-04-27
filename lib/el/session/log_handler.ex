defmodule El.Session.LogHandler do
  def handle_log(:log, state) do
    {:reply, state.messages, state}
  end

  def handle_log({:log, :all}, state) do
    {:reply, state.messages, state}
  end

  def handle_log({:log, count}, state) do
    {:reply, Enum.take(state.messages, -count), state}
  end
end
