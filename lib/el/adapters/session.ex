defmodule El.Adapters.Session do
  @callback start_link(opts :: keyword()) :: {:ok, pid()} | {:error, term()}
  @callback stream(pid :: pid(), prompt :: String.t()) :: term()
end
