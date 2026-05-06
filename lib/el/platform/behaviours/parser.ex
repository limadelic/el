defmodule El.Platform.Behaviours.Parser do
  @callback try_extract_result(String.t(), String.t()) :: :incomplete | {:ok, term(), String.t()}
end
