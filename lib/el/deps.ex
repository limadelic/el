defmodule El.Deps do
  def production do
    [
      el_module: Application.get_env(:el, :el_module, El),
      app: Application.get_env(:el, :app, El.Application),
      session: Application.get_env(:el, :session, El.Session),
      registry: Application.get_env(:el, :registry, Registry),
      supervisor: Application.get_env(:el, :supervisor, DynamicSupervisor),
      monitor: Application.get_env(:el, :monitor, El.ProcessMonitor),
      session_api: Application.get_env(:el, :session_api, El.Session.Api),
      agent_detector: Application.get_env(:el, :agent_detector, El.AgentDetector),
      agent_metadata: Application.get_env(:el, :agent_metadata, El.AgentMetadata),
      group_leader: Application.get_env(:el, :group_leader, El.GroupLeaderImpl),
      dets_backend: Application.get_env(:el, :dets_backend, El.DetsBackend),
      message_store: Application.get_env(:el, :message_store, El.MessageStore)
    ]
  end
end
