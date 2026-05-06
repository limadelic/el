defmodule El.Behaviours.ClaudePortCloser do
  @callback safe_close_port(port() | nil, module()) :: :ok
end
