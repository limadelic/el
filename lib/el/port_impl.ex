defmodule El.PortImpl do
  @behaviour El.Behaviours.Port

  @impl true
  def open(name, opts) do
    {:ok, Port.open(name, opts)}
  rescue
    e -> {:error, {:port_open_failed, e}}
  end

  @impl true
  def command(port, data), do: Port.command(port, data)

  @impl true
  def info(port), do: Port.info(port)

  @impl true
  def close(port), do: Port.close(port)
end
