defmodule El.CLI.Behaviours.TextFormatter do
  @callback format_response(term()) :: list()
end
