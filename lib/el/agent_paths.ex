defmodule El.Agent.Paths do
  def local_path(agent_name) do
    Path.join([".claude", "agents", "#{agent_name}.md"])
  end

  def global_path(agent_name) do
    home = System.get_env("HOME")
    Path.join([home, ".claude", "agents", "#{agent_name}.md"])
  end
end
