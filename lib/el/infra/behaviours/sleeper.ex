defmodule El.Infra.Behaviours.Sleeper do
  @callback sleep(integer()) :: :ok
end
