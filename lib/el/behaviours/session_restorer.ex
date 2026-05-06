defmodule El.Behaviours.SessionRestorer do
  @callback restore_sessions(keyword()) :: :ok
end
