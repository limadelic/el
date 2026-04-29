defmodule El.CLI.AgentDetector do
  def exists?(name) do
    project_path(name) |> File.exists?() or global_path(name) |> File.exists?()
  end

  def detect_agent(name) do
    if exists?(name), do: name, else: nil
  end

  defp project_path(name) do
    Path.join([File.cwd!(), ".claude", "agents", "#{name}.md"])
  end

  defp global_path(name) do
    Path.join([System.get_env("HOME"), ".claude", "agents", "#{name}.md"])
  end
end
