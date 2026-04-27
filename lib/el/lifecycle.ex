defmodule El.Lifecycle do
  def exit(:all) do
    El.ls() |> Enum.each(&El.Lifecycle.exit/1)
  end

  def exit(name) do
    do_exit(name)
  end

  defp do_exit(name) do
    case El.registry().lookup(El.Registry, name) do
      [{pid, _}] ->
        spawn(fn ->
          ref = Process.monitor(pid)
          El.supervisor().terminate_child(El.SessionSupervisor, pid)
          El.monitor().wait_for_down(ref, name)
        end)

        :ok

      [] ->
        El.app().delete_session_messages(name)
        :not_found
    end
  end
end
