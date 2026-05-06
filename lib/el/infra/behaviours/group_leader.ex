defmodule El.Infra.Behaviours.GroupLeader do
  @callback open_null_device() :: pid()
  @callback close(pid()) :: :ok
  @callback get() :: pid()
  @callback set(pid(), pid()) :: true
end
