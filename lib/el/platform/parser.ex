defmodule El.Platform.Parser do
  @behaviour El.ClaudePort.Behaviours.Parser
  @impl true
  def normalize_keys(json), do: ClaudeCode.CLI.Parser.normalize_keys(json)
end
