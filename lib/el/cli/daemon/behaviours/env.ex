defmodule El.CLI.Daemon.Behaviours.Env do
  @callback daemon_script() :: String.t()
  @callback daemon_node() :: atom()
  @callback daemon_cookie() :: atom()
  @callback dev?() :: boolean()
end
