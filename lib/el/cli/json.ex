defmodule El.CLI.Json do
  def execute_info(name, deps) do
    api = Keyword.get(deps, :session_api, El.Session.Api)
    print_info(api.alive?(String.to_atom(name)), name, deps)
  end

  defp print_info(false, name, _deps) do
    IO.puts(El.CLI.Output.Json.info(%{name: name, alive: false}))
  end

  defp print_info(true, name, deps) do
    api = Keyword.get(deps, :session_api, El.Session.Api)
    data = build_alive_data(name, String.to_atom(name), api)
    IO.puts(El.CLI.Output.Json.info(data))
  end

  defp build_alive_data(name, name_atom, api) do
    api.info(name_atom)
    |> Map.put(:name, name)
    |> Map.put(:agent, api.agent(name_atom))
    |> Map.put(:alive, true)
  end
end
