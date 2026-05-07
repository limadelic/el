defmodule El.CLI.Json do
  def execute_info(name, deps) do
    api = Keyword.get(deps, :session_api, El.Session.Api)
    print_info(api.alive?(String.to_atom(name)), name, deps)
  end

  defp print_info(false, name, _deps) do
    IO.puts(El.CLI.Output.Json.info(%{name: name, alive: false}))
  end
end
