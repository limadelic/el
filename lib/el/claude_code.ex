defmodule El.ClaudeCode do
  def start_link(opts) do
    session_name = Keyword.get(opts, :name)
    session_id = if session_name, do: Atom.to_string(session_name), else: nil

    # Get CLI config to avoid path conflicts
    cli_path = Application.get_env(:claude_code, :cli_path, :bundled)
    cli_dir = Application.get_env(:claude_code, :cli_dir)

    # Build adapter config with optional cli_dir
    adapter_config = [cli_path: cli_path]
    adapter_config = if cli_dir, do: adapter_config ++ [cli_dir: cli_dir], else: adapter_config

    # Start ClaudeCode with adapter and model config
    ClaudeCode.Session.start_link(
      adapter: {ClaudeCode.Adapter.Port, adapter_config},
      model: "claude-opus-4-7",
      session_id: session_id
    )
  end

  def stream(pid, prompt) do
    ClaudeCode.Session.stream(pid, prompt)
  end
end
