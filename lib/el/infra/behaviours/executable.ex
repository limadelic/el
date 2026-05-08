defmodule El.Infra.Behaviours.Executable do
  @callback find(charlist()) :: charlist() | false
end
