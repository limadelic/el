defmodule El.Session.AskCompleter do
  @callback complete(reporter :: pid, ask_info :: tuple, routes :: list) :: :ok
end
