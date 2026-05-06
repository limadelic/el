defmodule El.CLI.Start.DaemonHealth do
  def ping_if_agent(name_atom, opts, deps) do
    do_ping(name_atom, Keyword.get(opts, :agent), session_api(deps).info(name_atom), deps)
  end

  defp do_ping(_name_atom, nil, _info, _deps), do: :ok
  defp do_ping(_name_atom, _agent, %{messages: messages}, _deps) when messages > 0, do: :ok
  defp do_ping(name_atom, _agent, _info, deps), do: quiet_ask(name_atom, deps)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp quiet_ask(name_atom, deps) do
    {original, null_device, gl} = redirect_to_null(deps)
    ask_fn = fn -> session_api(deps).ask(name_atom, "who are you?") end
    try(do: ask_fn.(), after: restore_io(gl, original, null_device))
  end

  defp redirect_to_null(deps) do
    gl = group_leader(deps)
    null_device = gl.open_null_device()
    original = gl.get()
    gl.set(self(), null_device)
    {original, null_device, gl}
  end

  defp restore_io(gl, original, null_device) do
    gl.set(self(), original)
    gl.close(null_device)
  end

  def session_api(deps) do
    Keyword.get(deps, :session_api, El.Session.Api)
  end

  defp group_leader(deps) do
    Keyword.get(deps, :group_leader, El.GroupLeaderImpl)
  end
end
