defmodule El.Lifecycle do
  def exit(target, reason \\ :normal, opts \\ [])

  def exit(:all, reason, opts) do
    El.ls(opts) |> Enum.each(&El.Lifecycle.exit(&1, reason, opts))
  end

  def exit(name, reason, opts) do
    result = name |> lookup(opts) |> exit_found(name, opts)
    delete_stores(name, reason, opts)
    result
  end

  defp lookup(name, opts) do
    El.registry(opts).lookup(El.Registry, name)
  end

  defp exit_found([{pid, _}], name, opts) do
    terminate(pid, name, opts)
  rescue
    _ -> :ok
  end

  defp exit_found([], _name, _opts) do
    :not_found
  end

  defp terminate(pid, name, opts) do
    ref = Process.monitor(pid)
    El.supervisor(opts).terminate_child(El.SessionSupervisor, pid)
    app = Keyword.fetch!(opts, :app)
    El.monitor(opts).wait_for_down(ref, name, Keyword.put(opts, :app, app))
  end

  defp delete_stores(name, reason, opts) when reason in [:normal, :shutdown] do
    app = Keyword.fetch!(opts, :app)
    app.delete_session_messages(name, opts)
    session_meta = Keyword.get(opts, :session_meta, El.SessionMeta)
    session_meta.delete(name)
  end

  defp delete_stores(name, {:shutdown, _}, opts) do
    app = Keyword.fetch!(opts, :app)
    app.delete_session_messages(name, opts)
    session_meta = Keyword.get(opts, :session_meta, El.SessionMeta)
    session_meta.delete(name)
  end

  defp delete_stores(_name, _reason, _opts) do
    :ok
  end
end
