defmodule El do
  def start(name, opts \\ []) when is_atom(name) do
    case local_lookup(name) do
      [{_pid, _}] ->
        name

      [] ->
        DynamicSupervisor.start_child(El.SessionSupervisor, {El.Session, {name, opts}})
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

  def tell_ask(name, target, message) do
    El.Session.tell_ask(name, target, message)
  end

  def ask_tell(name, target, message) do
    El.Session.ask_tell(name, target, message)
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
    # Process already gone or errored
    _ -> :ok
  end

  def ls do
    local_ls()
    |> Enum.sort()
  end

  def local_ls do
    Registry.select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def local_lookup(name) do
    Registry.lookup(El.Registry, name)
  end
end
