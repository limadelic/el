defmodule El.Behaviours.SessionBootstrap do
  @callback handle_continue(map()) :: {:noreply, map()}
end
