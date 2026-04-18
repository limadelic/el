import Config

# Use global Claude CLI, with cache dir to avoid conflicts
config :claude_code,
  cli_path: :global,
  cli_dir: Path.expand("~/.cache/el-cli")
