defmodule El.Infra.FileSystem do
  @behaviour El.Infra.Behaviours.FileSystem

  @impl true
  def exists?(path) do
    File.exists?(path)
  end

  @impl true
  def cwd! do
    File.cwd!()
  end

  @impl true
  def mkdir_p!(path) do
    File.mkdir_p!(path)
  end
end
