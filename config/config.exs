import Config

# Use global Claude CLI path (should be in PATH as 'claude')
config :claude_code, cli_path: :global

config :cabbage, features: "features/"

config :logger, handle_sasl_reports: true
