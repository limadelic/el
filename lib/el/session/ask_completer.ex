defmodule El.Session.AskCompleter do
  @callback complete(target :: term, reporter :: pid, ask_info :: tuple, routes :: list) :: :ok
end
