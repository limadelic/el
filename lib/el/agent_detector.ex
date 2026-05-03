defmodule El.AgentDetector do
  @behaviour El.Behaviours.FileSystem

  def exists?(name, fs \\ file_system_impl()) do
    check_paths(fs, paths(name))
  end

  def cwd(fs \\ file_system_impl()) do
    fs.cwd()
  end

  def detect_agent(name, fs \\ file_system_impl()) do
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

  defp file_system_impl do
    Application.get_env(:el, :file_system, El.FileSystemImpl)
  end
end
