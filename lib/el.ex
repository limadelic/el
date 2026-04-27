defmodule El do
  def start(name, opts \\ []) when is_atom(name) do
    registry = Keyword.get(opts, :registry, Registry)
    supervisor = Keyword.get(opts, :supervisor, DynamicSupervisor)
    start_if_needed(name, opts, local_lookup(name, registry), supervisor)
  end

  defp start_if_needed(name, _opts, [{_pid, _}], _supervisor) do
    name
  end

  defp start_if_needed(name, opts, [], supervisor) do
    apply_safe(supervisor, :start_child, [El.SessionSupervisor, {El.Session, {name, opts}}])
    name
  end

  def tell(name, message, opts \\ []) do
    session = Keyword.get(opts, :session_module, El.Session)
    session.tell(name, message)
  end

  def ask(name, message, opts \\ []) do
    session = Keyword.get(opts, :session_module, El.Session)
    session.ask(name, message)
  end

  def log(name) do
    El.Session.log(name)
  end

  def log(name, count) do
    El.Session.log(name, count)
  end

  def clear(name, opts \\ []) do
    session = Keyword.get(opts, :session_module, El.Session)
    session.clear(name)
  end

  def tell_ask(name, target, message, opts \\ []) do
    session = Keyword.get(opts, :session_module, El.Session)
    session.tell_ask(name, target, message)
  end

  def ask_tell(name, target, message, opts \\ []) do
    session = Keyword.get(opts, :session_module, El.Session)
    session.ask_tell(name, target, message)
  end

  def exit(name_or_all, opts \\ [])

  def exit(:all, opts) do
    registry = Keyword.get(Keyword.take(opts, [:registry]), :registry, Registry)
    local_ls(registry) |> Enum.each(&El.exit(&1, opts))
  end

  def exit(name, opts) do
    do_exit(name, opts)
  end

  def exit_pattern(pattern, opts \\ []) do
    ls(opts)
    |> Enum.filter(&match_pattern?(&1, pattern))
    |> Enum.each(&El.exit(&1, opts))
  end

  def clear_pattern(pattern, opts \\ []) do
    session = Keyword.get(opts, :session_module, El.Session)
    ls(opts) |> Enum.filter(&match_pattern?(&1, pattern)) |> Enum.each(&session.clear(&1))
  end

  def log_pattern(pattern, count, opts \\ []) do
    session = Keyword.get(opts, :session_module, El.Session)

    ls(opts)
    |> Enum.filter(&match_pattern?(&1, pattern))
    |> Enum.flat_map(fn name ->
      case session.log(name, count) do
        :not_found -> []
        entries -> entries
      end
    end)
  end

  defp match_pattern?(name, pattern) do
    name_str = Atom.to_string(name)
    regex_pattern = pattern |> String.replace("*", ".*") |> String.replace("?", ".")
    Regex.match?(~r/^#{regex_pattern}$/, name_str)
  end

  defp do_exit(name, opts) do
    mods = Keyword.take(opts, [:registry, :supervisor, :monitor, :app])
    registry = Keyword.get(mods, :registry, Registry)
    supervisor = Keyword.get(mods, :supervisor, DynamicSupervisor)
    monitor = Keyword.get(mods, :monitor, El.ProcessMonitor)
    app = Keyword.get(mods, :app, El.Application)
    exit_if_found(name, local_lookup(name, registry), registry, supervisor, monitor, app)
  rescue
    _ -> :ok
  end

  defp exit_if_found(name, [{pid, _}], _registry, supervisor, monitor, _app) do
    ref = Process.monitor(pid)
    apply_safe(supervisor, :terminate_child, [El.SessionSupervisor, pid])
    apply_safe(monitor, :wait_for_down, [ref, name])
  end

  defp exit_if_found(name, [], _registry, _supervisor, _monitor, app) do
    app.delete_session_messages(name)
    :not_found
  end

  def ls(opts \\ []) do
    registry = Keyword.get(opts, :registry, Registry)

    local_ls(registry)
    |> Enum.sort()
  end

  defp local_ls(registry) do
    apply_safe(registry, :select, [El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}]])
  end

  defp local_lookup(name, registry) do
    apply_safe(registry, :lookup, [El.Registry, name])
  end

  defp apply_safe(module, func, args) do
    apply(module, func, args)
  rescue
    _ -> []
  end
end
