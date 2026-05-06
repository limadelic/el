defmodule El.Platform.Parser do
  @behaviour El.Platform.Behaviours.Parser
  @impl true
  def normalize_keys(json), do: ClaudeCode.CLI.Parser.normalize_keys(json)
end
