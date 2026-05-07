defmodule El.Infra.System do
  @behaviour El.Infra.Behaviours.System
  defdelegate cmd(command, args), to: System
end
