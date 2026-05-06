defmodule El.Infra.NetKernel do
  @behaviour El.Behaviours.NetKernel

  @impl true
  defdelegate start(args), to: :net_kernel
end
