defmodule El.ClaudeCode do
  @default_session_module ClaudeCode.Session

  def start_link(opts) do
    session_module = opts[:session_module] || @default_session_module
    session_id = random_uuid()

    cli_path = Application.get_env(:claude_code, :cli_path, :global)

    session_opts = [
      adapter: {ClaudeCode.Adapter.Port, [cli_path: cli_path]},
      session_id: session_id,
      dangerously_skip_permissions: true
    ]

    session_opts =
      if model = opts[:model] do
        session_opts ++ [model: model]
      else
        session_opts
      end

    session_module.start_link(session_opts)
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
