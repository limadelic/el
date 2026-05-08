defmodule El.ClaudePort.Behaviours.ParserExtract do
  @callback try_extract_result(String.t(), String.t()) :: :incomplete | {:ok, term(), String.t()}
end
