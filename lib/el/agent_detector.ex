defmodule El.AgentDetector do
  def exists?(name) do
    check_paths([global_path(name), local_path(name)])
  end

  def detect_agent(name), do: exists?(name) && name

  defp check_paths(paths) do
    Enum.any?(paths, &File.exists?/1)
  end

  defp global_path(name) do
    home = System.get_env("HOME")
    Path.join([home, ".claude", "agents", "#{name}.md"])
  end

  defp local_path(name) do
    Path.join([".claude", "agents", "#{name}.md"])
  end
end
