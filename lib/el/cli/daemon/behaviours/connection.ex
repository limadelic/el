defmodule El.CLI.Daemon.Behaviours.Connection do
  @callback connect_to_daemon(keyword()) :: {:ok, atom()} | :local
  @callback ensure_daemon(keyword()) :: :ok | {:error, term()}
  @callback start_daemon_node(keyword()) :: :ok
end
