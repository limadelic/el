defmodule El.FileSystemImpl do
  @behaviour El.Behaviours.FileSystem

  def exists?(path) do
    File.exists?(path)
  end
end
