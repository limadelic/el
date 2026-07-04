defmodule El do
  @behaviour El.Behaviours.El

  @impl true
  def start(name, opts \\ []) when is_atom(name) do
    start_if_needed(name, opts, El.Deps.registry(opts).lookup(El.Registry, name))
  end

  defp start_if_needed(_name, _opts, [{_pid, _}]) do
    :already_running
  end

  defp start_if_needed(name, opts, []) do
    filtered_opts = filter_session_opts(opts)
    start_session_child(name, opts, filtered_opts)
    :created
  end

  defp start_session_child(name, opts, filtered_opts) do
    El.Deps.supervisor(opts).start_child(El.SessionSupervisor, session_spec(name, filtered_opts))
  end

  defp session_spec(name, opts) do
    %{
      id: name,
      start: {El.Session.Api, :start_link, [{name, opts}]},
      restart: :temporary
    }
  end

  defp filter_session_opts(opts) do
    Keyword.drop(opts, [:registry, :supervisor, :monitor, :app])
  end

  @impl true
  def tell(name, message, opts \\ []) do
    session_api(opts).tell(name, message)
  end

  @impl true
  def ask(name, message, opts \\ []) do
    session_api(opts).ask(name, message)
  end

  @impl true
  def log(name, count \\ nil, opts \\ [])
  def log(name, nil, opts), do: session_api(opts).log(name)
  def log(name, count, opts), do: session_api(opts).log(name, count)

  @impl true
  def clear(name, opts \\ []) do
    session_api(opts).clear(name)
  end

  @impl true
  def agent(name, opts \\ []), do: session_api(opts).agent(name)
  defp session_api(opts), do: Keyword.fetch!(opts, :session_api)

  @impl true
  def exit(name, opts \\ []) do
    El.Lifecycle.exit(name, :normal, opts)
  end

  @impl true
  def restart(name, opts \\ []) do
    El.Lifecycle.exit(name, :restart, opts)
    resume_session(name, opts)
  end

  defp resume_session(name, opts) do
    session_meta = Keyword.get(opts, :session_meta, El.Session.Meta)
    resume_with_session_meta(name, opts, session_meta.lookup(name))
  end

  defp resume_with_session_meta(name, opts, {:ok, session_id, agent, model}) do
    resume_opts = [resume: session_id, agent: agent, model: model] ++ opts
    start(name, resume_opts)
  end

  @impl true
  defdelegate restart_pattern(pattern, opts \\ []), to: El.Pattern, as: :restart

  @impl true
  defdelegate exit_pattern(pattern, opts \\ []), to: El.Pattern, as: :exit

  @impl true
  defdelegate clear_pattern(pattern, opts \\ []), to: El.Pattern, as: :clear

  @impl true
  defdelegate log_pattern(pattern, count, opts \\ []), to: El.Pattern, as: :log

  @impl true
  def ls(opts \\ []) do
    session_registry = Application.get_env(:el, :session_registry, El.Session.Registry)
    session_registry.list(opts)
  end
end
