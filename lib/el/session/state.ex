defmodule El.Session.State do
  @defaults %{
    claude_module: El.ClaudePort,
    claude_session: El.Session.Claude.Driver,
    task_module: Task,
    ask_module: El.Session.Commands.Ask,
    alive_fn: &El.Session.Api.alive?/1,
    registry_module: El.Session.Registry,
    store_module: El.MessageStore.Facade,
    session_meta: El.Session.Meta,
    session_api: El.Session.Api,
    el_module: El,
    bootstrap_module: El.Session.Lifecycle.Bootstrap
  }
  @base_state_defaults %{
    name: nil,
    claude_pid: nil,
    session_id: nil,
    cwd: nil,
    messages: [],
    pending_calls: [],
    opts: []
  }

  def build(name, opts, rest, session_id, cwd) do
    base_state(name, session_id, cwd, opts)
    |> Map.merge(modules_and_callbacks(opts))
    |> Map.put(:claude_opts, El.Session.ClaudeOpts.build(rest, opts, session_id))
  end

  defp base_state(n, s, c, o),
    do: @base_state_defaults |> Map.merge(%{name: n, session_id: s, cwd: c, opts: o})

  defp modules_and_callbacks(o), do: get_opts(o)

  defp get_opts(o), do: @defaults |> Map.merge(Map.new(o))
end
