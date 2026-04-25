import Config

config :logger, level: :info
config :el, restart_fn: fn -> :ok end
