defmodule El.ClaudeCode do
  def start_link(opts) do
    # Map El session name to ClaudeCode session if provided
    session_name = Keyword.get(opts, :name)

    # Start ClaudeCode with adapter and model config
    ClaudeCode.Session.start_link(
      adapter: {ClaudeCode.Adapter.Port, cli_path: :bundled},
      model: "claude-opus-4-7",
      session_id: session_name
    )
  end

  def stream(pid, prompt) do
    ClaudeCode.Session.stream(pid, prompt)
  end
end
