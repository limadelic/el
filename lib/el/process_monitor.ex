defmodule El.ProcessMonitor do
  def wait_for_down(ref, name) do
    receive do
      {:DOWN, ^ref, :process, _, _} -> cleanup(name)
    after
      5000 -> cleanup(name)
    end
  end

  defp cleanup(name) do
    El.Application.delete_session_messages(name)
    :ok
  end
end
