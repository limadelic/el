defmodule El.Session.Behaviours.Registry do
  @callback list(Keyword.t()) :: [String.t()]
end
