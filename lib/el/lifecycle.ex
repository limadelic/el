defmodule El.Lifecycle do
  def exit(:all) do
    El.ls() |> Enum.each(&El.Lifecycle.exit/1)
  end

  def exit(name) do
    do_exit(name)
  end

  defp do_exit(name) do
    exit_if_found(name, El.registry().lookup(El.Registry, name))
  rescue
    _ -> :ok
  end

  defp exit_if_found(name, [{pid, _}]) do
    ref = Process.monitor(pid)
    El.supervisor().terminate_child(El.SessionSupervisor, pid)
    El.monitor().wait_for_down(ref, name)
  end

  defp exit_if_found(name, []) do
    El.app().delete_session_messages(name)
    :not_found
  end
end
