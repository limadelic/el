defmodule El.ClaudeCode do
  def start_link(opts) do
    # Map El session name to ClaudeCode session if provided
    session_name = Keyword.get(opts, :name)
    session_id = if session_name, do: Atom.to_string(session_name), else: nil

    # Use config-specified cli_path (should be :global from config.exs)
    cli_path = Application.get_env(:claude_code, :cli_path, :bundled)

    # Start ClaudeCode with adapter and model config
    ClaudeCode.Session.start_link(
      adapter: {ClaudeCode.Adapter.Port, cli_path: cli_path},
      model: "claude-opus-4-7",
      session_id: session_id
    )
  end

  def stream(pid, prompt) do
    ClaudeCode.Session.stream(pid, prompt)
  end
end
