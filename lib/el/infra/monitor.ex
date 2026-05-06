defmodule El.Infra.Monitor do
  @behaviour El.Infra.Behaviours.Monitor

  def wait_for_down(ref, name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    app = Keyword.get(opts, :app, El.Application)
    do_wait(ref, name, timeout, app, opts)
  end

  defp do_wait(ref, name, timeout, app, opts) do
    receive do
      {:DOWN, ^ref, :process, _, _} -> cleanup(name, app, opts)
    after
      timeout -> cleanup(name, app, opts)
    end
  end

  defp cleanup(name, app, opts) do
    app.delete_session_messages(name, opts)
    :ok
  end
end
