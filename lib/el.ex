defmodule El do
  def start(name) when is_atom(name) do
    case local_lookup(name) do
      [{_pid, _}] -> name
      [] -> DynamicSupervisor.start_child(El.SessionSupervisor, {El.Session, name})
           El.SessionTracker.track(name)
           name
    end
  end

  def tell(name, message) do
    El.Session.tell(name, message)
  end

  def ask(name, message) do
    El.Session.ask(name, message)
  end

  def log(name) do
    El.Session.log(name)
  end

  def kill(name) do
    case local_lookup(name) do
      [{pid, _}] ->
        # Terminate the child in the supervisor
        # Use terminate instead of call, which will prevent restart
        DynamicSupervisor.terminate_child(El.SessionSupervisor, pid)
        :ok
      [] ->
        :not_found
    end
  rescue
    _ -> :ok  # Process already gone or errored
  end

  def ls do
    local_ls()
    |> Enum.sort()
  end

  def local_ls do
    El.SessionTracker.all()
  end

  def local_lookup(name) do
    Registry.lookup(El.Registry, name)
  end
end
