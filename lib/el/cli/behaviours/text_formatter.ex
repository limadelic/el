defmodule El.CLI.Behaviours.TextFormatter do
  @callback format_response(term()) :: list()
  @callback format_prompt(term()) :: list()
end
