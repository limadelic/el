defmodule El.AgentDetector do
  @behaviour El.Behaviours.FileSystem

  def exists?(name, fs \\ file_system_impl()) do
    check_paths(fs, [global_path(name), local_path(name)])
  end

  def detect_agent(name, fs \\ file_system_impl()) do
    exists?(name, fs) && name || nil
  end

  defp check_paths(fs, paths) do
    Enum.any?(paths, &fs.exists?/1)
  end

  defp global_path(name) do
    home = System.get_env("HOME")
    Path.join([home, ".claude", "agents", "#{name}.md"])
  end

  defp local_path(name) do
    Path.join([".claude", "agents", "#{name}.md"])
  end

  defp file_system_impl do
    Application.get_env(:el, :file_system, El.FileSystemImpl)
  end
end
