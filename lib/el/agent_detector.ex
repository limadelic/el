defmodule El.AgentDetector do
  def exists?(name) do
    home = System.get_env("HOME")
    global_path = Path.join([home, ".claude", "agents", "#{name}.md"])
    local_path = Path.join([".claude", "agents", "#{name}.md"])

    File.exists?(global_path) or File.exists?(local_path)
  end

  def detect_agent(name) do
    if exists?(name), do: name, else: nil
  end
end
