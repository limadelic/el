defmodule El.Infra.Behaviours.NetKernel do
  @callback start([atom()]) :: {:ok, pid()} | {:error, term()}
end
