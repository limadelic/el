defmodule El.Infra.JSONDecoder do
  @behaviour El.Infra.Behaviours.JSONDecoder
  @impl true
  def decode(line), do: Jason.decode(line)
end
