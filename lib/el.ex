defmodule El do
  def start(name) when is_atom(name) do
    case Registry.lookup(El.Registry, name) do
      [{_pid, _}] -> name
      [] -> DynamicSupervisor.start_child(El.SessionSupervisor, {El.Session, name})
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
    case Registry.lookup(El.Registry, name) do
      [{pid, _}] -> GenServer.stop(pid)
      [] -> :not_found
    end
  end

  def ls do
    El.Registry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [:"$1"]}])
    |> Enum.sort()
  end
end
