defmodule El.Platform.Behaviours.CodeSession do
  @callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  @callback stream(pid(), binary()) :: Enumerable.t()
end
