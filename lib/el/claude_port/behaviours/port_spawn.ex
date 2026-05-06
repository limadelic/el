defmodule El.ClaudePort.Behaviours.PortSpawn do
  @callback spawn({:ok, {String.t(), [String.t()]}} | {:error, term()}, map()) ::
              {:ok, port()} | {:error, term()}
end
