import Config

# Use global Claude CLI path (should be in PATH as 'claude')
config :claude_code, cli_path: :global

config :cabbage, features: "features/"

config :logger,
  level: :error,
  handle_sasl_reports: false

config :sasl, sasl_error_logger: :silent
