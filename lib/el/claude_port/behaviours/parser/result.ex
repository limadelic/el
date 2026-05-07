defmodule El.ClaudePort.Behaviours.Parser.Result do
  @callback merge(map(), {any(), String.t() | nil, String.t() | nil}) ::
              {{any(), String.t() | nil, String.t() | nil}, boolean()}
  @callback finalize(any(), String.t() | nil, String.t() | nil, String.t()) ::
              {any(), String.t() | nil, String.t()}
end
