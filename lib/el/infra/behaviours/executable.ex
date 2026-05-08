defmodule El.Infra.Behaviours.Executable do
  @callback find(String.t()) :: charlist() | false
end
