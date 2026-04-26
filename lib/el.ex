defmodule El do
  def start(name, opts \\ []) when is_atom(name) do
    start_if_needed(name, opts, local_lookup(name))
  end

  defp start_if_needed(name, _opts, [{_pid, _}]) do
    name
  end

  defp start_if_needed(name, opts, []) do
    DynamicSupervisor.start_child(El.SessionSupervisor, {El.Session, {name, opts}})
    name
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

  def log(name, count) do
    El.Session.log(name, count)
  end

  def clear(name) do
    El.Session.clear(name)
  end

  def tell_ask(name, target, message) do
    El.Session.tell_ask(name, target, message)
  end

  def ask_tell(name, target, message) do
    El.Session.ask_tell(name, target, message)
  end

  def exit(:all) do
    local_ls() |> Enum.each(&El.exit/1)
  end

  def exit(name) do
    exit_if_found(name, local_lookup(name))
  rescue
    _ -> :ok
  end

  defp exit_if_found(name, [{pid, _}]) do
    ref = Process.monitor(pid)
    DynamicSupervisor.terminate_child(El.SessionSupervisor, pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _} ->
        El.Application.delete_session_messages(name)
        :ok
    after
      5000 ->
        El.Application.delete_session_messages(name)
        :ok
    end
  end

  defp exit_if_found(_name, []) do
    :not_found
  end

  def ls do
    local_ls()
    |> Enum.sort()
  end

  defp local_ls do
    Registry.select(El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  defp local_lookup(name) do
    Registry.lookup(El.Registry, name)
  end
end
