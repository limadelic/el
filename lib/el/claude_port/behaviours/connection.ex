defmodule El.ClaudePort.Behaviours.Connection do
  @callback handle_connect(map()) :: {:noreply, map()}
  @callback handle_ask(map(), String.t(), GenServer.from()) :: {:noreply, map()} | {:reply, term(), map()}
end
