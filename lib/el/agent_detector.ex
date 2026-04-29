defmodule El.AgentDetector do
  def exists?(name) do
    check_paths([global_path(name), local_path(name)])
  end

  def detect_agent(name) do
    case exists?(name) do
      true -> name
      false -> nil
    end
  end

  defp check_paths([path | rest]) do
    File.exists?(path) || check_paths(rest)
  end

  defp check_paths([]) do
    false
  end

  defp global_path(name) do
    home = System.get_env("HOME")
    Path.join([home, ".claude", "agents", "#{name}.md"])
  end

  defp local_path(name) do
    Path.join([".claude", "agents", "#{name}.md"])
  end
end
