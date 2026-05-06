defmodule El.Agent.Detector do
  @behaviour El.Agent.Behaviours.Detector
  @behaviour El.Infra.Behaviours.FileSystem

  def exists?(name, fs \\ El.Infra.FileSystem) do
    check_paths(fs, paths(name))
  end

  def cwd(fs \\ El.Infra.FileSystem) do
    fs.cwd()
  end

  def mkdir_p!(path, fs \\ El.Infra.FileSystem) do
    fs.mkdir_p!(path)
  end

  def detect_agent(name, fs \\ El.Infra.FileSystem) do
    paths(name) |> Enum.find(&fs.exists?/1) |> found(name)
  end

  defp paths(name) do
    [El.Agent.Paths.global_path(name), El.Agent.Paths.local_path(name)]
  end

  defp found(nil, _), do: nil
  defp found(_, name), do: name

  defp check_paths(fs, paths) do
    Enum.any?(paths, &fs.exists?/1)
  end
end
