defmodule El.CCParser do
  @behaviour El.Behaviours.CCParser
  @impl true
  def normalize_keys(json), do: ClaudeCode.CLI.Parser.normalize_keys(json)
end
