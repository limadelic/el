defmodule El.CLI.Behaviours.CardBox do
  @callback box_frame(list()) :: list()
  @callback frame_pair_row(String.t(), String.t()) :: String.t()
end
