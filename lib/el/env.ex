defmodule El.Env do
  @behaviour El.Behaviours.Env

  @impl true
  def get(name), do: System.get_env(name)
end
