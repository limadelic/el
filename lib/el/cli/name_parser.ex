defmodule El.CLI.NameParser do
  def split(name) do
    agent = String.split(name, "@") |> List.first()
    {name, agent}
  end
end
