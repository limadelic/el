defmodule El.Lifecycle do
  def exit(:all) do
    El.ls() |> Enum.each(&El.Lifecycle.exit/1)
  end

  def exit(name), do: exit(name, :normal, [])

  def exit(name, reason), do: exit(name, reason, [])

  def exit(name, reason, deps) do
    name |> lookup() |> exit_found(name, deps)
    delete_stores(name, reason, deps)
  end

  defp lookup(name) do
    El.registry().lookup(El.Registry, name)
  end

  defp exit_found([{pid, _}], name, deps) do
    terminate(pid, name, deps)
  rescue
    _ -> :ok
  end

  defp exit_found([], _name, _deps) do
    :not_found
  end

  defp terminate(pid, name, deps) do
    ref = Process.monitor(pid)
    El.supervisor().terminate_child(El.SessionSupervisor, pid)
    El.monitor(deps).wait_for_down(ref, name)
  end

  defp delete_stores(name, reason, deps) when reason in [:normal, :shutdown] do
    El.app().delete_session_messages(name)
    session_meta = Keyword.get(deps, :session_meta, El.SessionMeta)
    session_meta.delete(name)
  end

  defp delete_stores(name, {:shutdown, _}, deps) do
    El.app().delete_session_messages(name)
    session_meta = Keyword.get(deps, :session_meta, El.SessionMeta)
    session_meta.delete(name)
  end

  defp delete_stores(_name, _reason, _deps) do
    :ok
  end
end
