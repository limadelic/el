defmodule El.PortAdapter do
  @callback open(port_name :: {atom(), String.t()}, options :: list()) :: port()
  @callback command(port :: port(), data :: binary()) :: true
end
