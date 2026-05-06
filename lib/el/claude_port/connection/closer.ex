defmodule El.ClaudePort.Connection.Closer do
  @behaviour El.ClaudePort.Behaviours.Closer

  def safe_close_port(nil, _port_module), do: :ok
  def safe_close_port(port, port_module), do: try_close(port_module.info(port), port, port_module)

  defp try_close(nil, _port, _port_module), do: :ok
  defp try_close(_info, port, port_module), do: close_with_rescue(port, port_module)

  defp close_with_rescue(port, port_module) do
    port_module.close(port)
  rescue
    ArgumentError -> :ok
  end
end
