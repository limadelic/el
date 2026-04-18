defmodule El.ClaudeCode do
  def start_link(opts) do
    session_name = Keyword.get(opts, :name)
    session_id = if session_name, do: Atom.to_string(session_name), else: nil

    # Start ClaudeCode with adapter and model config
    # Uses :global from config (expects 'claude' in PATH)
    ClaudeCode.Session.start_link(
      adapter: {ClaudeCode.Adapter.Port, cli_path: :global},
      model: "claude-opus-4-7",
      session_id: session_id
    )
  end

  def stream(pid, prompt) do
    ClaudeCode.Session.stream(pid, prompt)
  end
end
