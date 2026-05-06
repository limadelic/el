defmodule El.Deps do
  def production do
    core_modules() ++ supervision() ++ session_meta() ++ io_storage()
  end

  defp core_modules do
    [
      el_module: Application.get_env(:el, :el_module, El),
      app: Application.get_env(:el, :app, El.MessageStore.Facade),
      session: Application.get_env(:el, :session, El.Session),
      init_module: Application.get_env(:el, :init_module, El.MessageStore.Init)
    ]
  end

  defp supervision do
    [
      registry: Application.get_env(:el, :registry, Registry),
      supervisor: Application.get_env(:el, :supervisor, DynamicSupervisor),
      monitor: Application.get_env(:el, :monitor, El.ProcessMonitor)
    ]
  end

  defp session_meta do
    [
      session_api: Application.get_env(:el, :session_api, El.Session.Api),
      agent_detector: Application.get_env(:el, :agent_detector, El.AgentDetector),
      agent_metadata: Application.get_env(:el, :agent_metadata, El.AgentMetadata)
    ]
  end

  defp io_storage do
    [
      group_leader: Application.get_env(:el, :group_leader, El.GroupLeaderImpl),
      dets_backend: Application.get_env(:el, :dets_backend, El.DetsBackend),
      message_store: Application.get_env(:el, :message_store, El.MessageStore)
    ]
  end
end
