defmodule El.CLI.OutputJson do
  def info(%{alive: true} = data), do: Jason.encode!(data)

  def info(%{alive: false, name: name}) do
    Jason.encode!(%{name: name, alive: false})
  end
end
