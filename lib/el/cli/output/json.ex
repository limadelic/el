defmodule El.CLI.Output.Json do
  def info(data), do: Jason.encode!(data)
end
