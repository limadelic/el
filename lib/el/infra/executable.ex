defmodule El.Infra.Executable do
  @behaviour El.Infra.Behaviours.Executable

  @impl true
  def find(name), do: :os.find_executable(name)
end
