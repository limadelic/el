defmodule El.ProcessMonitor do
  def wait_for_down(ref, name) do
    receive do
      {:DOWN, ^ref, :process, _, _} ->
        El.Application.delete_session_messages(name)
        :ok
    after
      5000 ->
        El.Application.delete_session_messages(name)
        :ok
    end
  end
end
