defmodule El.Lifecycle do
  def exit(:all) do
    El.ls() |> Enum.each(&El.Lifecycle.exit/1)
  end

  def exit(name), do: do_exit(name)

  defp do_exit(name) do
    name |> lookup() |> exit_found(name)
    delete_stores(name)
  end

  defp lookup(name) do
    El.registry().lookup(El.Registry, name)
  end

  defp exit_found([{pid, _}], name) do
    terminate(pid, name)
  rescue
    _ -> :ok
  end

  defp exit_found([], _name) do
    :not_found
  end

  defp terminate(pid, name) do
    ref = Process.monitor(pid)
    El.supervisor().terminate_child(El.SessionSupervisor, pid)
    El.monitor().wait_for_down(ref, name)
  end

  defp delete_stores(name) do
    El.app().delete_session_messages(name)
    session_meta = Application.get_env(:el, :session_meta, El.SessionMeta)
    session_meta.delete(name)
  end
end
