defmodule El.SleeperImpl do
  @behaviour El.Behaviours.Sleeper

  @impl true
  def sleep(ms) do
    :timer.sleep(ms)
    :ok
  end
end
