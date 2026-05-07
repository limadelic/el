defmodule El.Session.Behaviours.Restorer do
  @callback restore_opts() :: keyword()
  @callback restore_sessions(keyword()) :: :ok
end
