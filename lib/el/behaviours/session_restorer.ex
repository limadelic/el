defmodule El.Behaviours.SessionRestorer do
  @callback restore_opts() :: keyword()
  @callback restore_sessions(keyword()) :: :ok
end
