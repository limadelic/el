defmodule El.CLI.Behaviours.Daemon do
  @callback restart_daemon(keyword()) :: :ok
end
