defmodule El.Infra.Env do
  @behaviour El.Infra.Behaviours.Env

  @impl true
  def get, do: System.get_env()

  @impl true
  def get(name), do: System.get_env(name)
end
