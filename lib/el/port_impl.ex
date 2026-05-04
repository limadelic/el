defmodule El.PortImpl do
  @behaviour El.Behaviours.Port

  @impl true
  def open(name, opts), do: Port.open(name, opts)

  @impl true
  def command(port, data), do: Port.command(port, data)

  @impl true
  def info(port), do: Port.info(port)

  @impl true
  def close(port), do: Port.close(port)
end
