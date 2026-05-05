defmodule El.NetKernelImpl do
  @behaviour El.Behaviours.NetKernel

  @impl true
  defdelegate start(args), to: :net_kernel
end
