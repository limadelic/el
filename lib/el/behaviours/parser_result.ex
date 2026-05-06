defmodule El.Behaviours.ParserResult do
  @callback merge(map(), {any(), String.t() | nil, String.t() | nil}) ::
              {{any(), String.t() | nil, String.t() | nil}, boolean()}
end
