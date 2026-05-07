defmodule El.Session.Behaviours.Bootstrap do
  @callback handle_continue(map()) :: {:noreply, map()}
end
