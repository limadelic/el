defmodule El.Infra.FileSystem do
  @behaviour El.Behaviours.FileSystem

  def exists?(path) do
    File.exists?(path)
  end

  def cwd do
    File.cwd!()
  end

  def mkdir_p!(path) do
    File.mkdir_p!(path)
  end
end
