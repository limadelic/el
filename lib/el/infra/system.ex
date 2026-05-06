defmodule El.Infra.System do
  @behaviour El.Behaviours.System
  defdelegate cmd(command, args), to: System
end
