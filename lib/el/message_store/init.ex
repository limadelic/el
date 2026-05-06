defmodule El.MessageStore.Init do
  def dets_path(dir, file) do
    Path.expand("#{dir}/#{file}.dets") |> String.to_charlist()
  end
end
