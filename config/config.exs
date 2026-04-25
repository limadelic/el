import Config

# Use global Claude CLI path (should be in PATH as 'claude')
config :claude_code, cli_path: :global

config :logger,
  level: :error,
  handle_sasl_reports: false
