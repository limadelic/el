defmodule El.Deps do
  def production do
    core_modules() ++ supervision() ++ session_meta() ++ session_infra() ++ io_storage()
  end

  def monitor(opts), do: Keyword.fetch!(opts, :monitor)
  def supervisor(opts), do: Keyword.fetch!(opts, :supervisor)
  def registry(opts), do: Keyword.fetch!(opts, :registry)
  def session_registry(opts), do: Keyword.fetch!(opts, :session_registry)

  defp dep(key, default) do
    {key, Application.get_env(:el, key, default)}
  end

  defp core_modules do
    core_basics() ++ core_init_restorer() ++ core_bootstrap() ++ core_ports()
  end

  defp core_basics do
    [dep(:el_module, El), dep(:app, El.MessageStore.Facade), dep(:session, El.Session)]
  end

  defp core_init_restorer do
    [dep(:init_module, El.MessageStore.Init), dep(:restorer_module, El.Session.Lifecycle.Restorer)]
  end

  defp core_bootstrap do
    [dep(:bootstrap_module, El.Session.Lifecycle.Bootstrap), dep(:connection_module, El.ClaudePort.Connection)]
  end

  defp core_ports do
    [dep(:cli_resolver_module, El.ClaudePort.Connection.CliResolver), dep(:port_spawn_module, El.ClaudePort.Connection.PortSpawn), dep(:closer_module, El.ClaudePort.Connection.Closer)]
  end

  defp supervision do
    [
      dep(:registry, Registry),
      dep(:supervisor, DynamicSupervisor),
      dep(:monitor, El.Infra.Monitor)
    ]
  end

  defp session_infra do
    [
      dep(:session_registry, El.Session.Registry.Impl)
    ]
  end

  defp session_meta do
    [
      dep(:session_api, El.Session.Api),
      dep(:agent_detector, El.Agent.Detector),
      dep(:agent_metadata, El.Agent.Metadata)
    ]
  end

  defp io_storage do
    [
      dep(:group_leader, El.Infra.GroupLeader),
      dep(:dets_backend, El.MessageStore.Backend),
      dep(:message_store, El.MessageStore)
    ]
  end
end
