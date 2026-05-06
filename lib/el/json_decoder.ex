defmodule El.JSONDecoder do
  @behaviour El.Behaviours.JSONDecoder
  @impl true
  def decode(line), do: Jason.decode(line)
end
