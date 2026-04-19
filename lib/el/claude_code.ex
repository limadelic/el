defmodule El.ClaudeCode do
  def start_link(_opts) do
    session_id = random_uuid()

    cli_path = Application.get_env(:claude_code, :cli_path, :global)

    ClaudeCode.Session.start_link(
      adapter: {ClaudeCode.Adapter.Port, [cli_path: cli_path]},
      model: "claude-opus",
      session_id: session_id
    )
  end

  def stream(pid, prompt) do
    ClaudeCode.Session.stream(pid, prompt)
  end

  defp random_uuid do
    bytes = :crypto.strong_rand_bytes(16)
    hex = Base.encode16(bytes, case: :lower)

    "#{String.slice(hex, 0, 8)}-#{String.slice(hex, 8, 4)}-#{String.slice(hex, 12, 4)}-#{String.slice(hex, 16, 4)}-#{String.slice(hex, 20, 12)}"
  end
end
