defmodule El.MessageStore.Init do
  def dets_path(dir, file) do
    Path.expand("#{dir}/#{file}.dets") |> String.to_charlist()
  end

  def store_dir(true), do: "~/.el/dev"
  def store_dir(false), do: "~/.el"
  def store_dir(daemon) when is_atom(daemon), do: store_dir(daemon.dev?())

  def open_dets(backend, name, path) do
    {:ok, _} = backend.open_file(name, file: path, type: :bag)
  end
end
