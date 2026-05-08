defmodule El.CLI.Info do
  alias El.CLI.{Start, Json, Output}

  def execute(args, deps) do
    [name] = args
    session_api = Keyword.get(deps, :session_api, El.Session.Api)
    print_info(session_api.alive?(String.to_atom(name)), name, session_api, deps)
  end

  def execute_json(args, deps) do
    [name] = args
    Json.execute_info(name, deps)
  end

  defp print_info(true, name, session_api, deps) do
    name_atom = String.to_atom(name)
    info = session_api.info(name_atom)
    opts = build_opts(session_api.agent(name_atom), info[:model])
    Start.print_session_info(name, opts, deps)
  end

  defp print_info(false, _name, _session_api, _deps) do
    IO.puts(Output.usage_message())
  end

  defp build_opts(agent, model) do
    []
    |> maybe_put(:agent, agent)
    |> maybe_put(:model, model)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]
end
