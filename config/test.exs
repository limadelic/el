import Config

config :logger, level: :info
config :el, restart_fn: fn -> :ok end

config :el,
  registry: El.MockRegistry,
  supervisor: El.MockSupervisor,
  session: El.MockSession,
  app: El.MockApp,
  monitor: El.MockMonitor
