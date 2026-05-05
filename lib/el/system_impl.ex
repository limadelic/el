defmodule El.SystemImpl do
  @behaviour El.Behaviours.System
  defdelegate cmd(command, args), to: System
end
