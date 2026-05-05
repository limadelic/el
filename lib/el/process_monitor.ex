defmodule El.ProcessMonitor do
  @behaviour El.Behaviours.Monitor

  def wait_for_down(ref, name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    app = Keyword.get(opts, :app, El.Application)
    do_wait(ref, name, timeout, app)
  end

  defp do_wait(ref, name, timeout, app) do
    receive do
      {:DOWN, ^ref, :process, _, _} -> cleanup(name, app)
    after
      timeout -> cleanup(name, app)
    end
  end

  defp cleanup(name, app) do
    app.delete_session_messages(name)
    :ok
  end
end
