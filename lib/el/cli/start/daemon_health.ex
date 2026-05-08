defmodule El.CLI.Start.DaemonHealth do
  def ping_for_session_id(name_atom, _opts, deps) do
    info = session_api(deps).info(name_atom)
    agent = session_api(deps).agent(name_atom)
    do_ping(name_atom, agent, info, deps)
  end

  defp do_ping(_name_atom, _agent, %{messages: messages}, _deps) when messages > 0, do: :ok
  defp do_ping(name_atom, nil, _info, deps), do: quiet_call(name_atom, deps, &probe/3)
  defp do_ping(name_atom, _agent, _info, deps), do: quiet_call(name_atom, deps, &ask/3)

  defp probe(name_atom, message, deps), do: session_api(deps).probe_ask(name_atom, message)
  defp ask(name_atom, message, deps), do: session_api(deps).ask(name_atom, message)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp quiet_call(name_atom, deps, fun) do
    {original, null_device, gl} = redirect_to_null(deps)
    call_fn = fn -> fun.(name_atom, "who are you?", deps) end
    try(do: call_fn.(), after: restore_io(gl, original, null_device))
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
    Keyword.get(deps, :group_leader, El.Infra.GroupLeader)
  end
end
