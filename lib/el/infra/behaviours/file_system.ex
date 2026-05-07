defmodule El.Infra.Behaviours.FileSystem do
  @callback exists?(String.t()) :: boolean()
  @callback cwd() :: String.t()
  @callback mkdir_p!(String.t()) :: :ok
end
