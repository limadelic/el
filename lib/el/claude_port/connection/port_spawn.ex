defmodule El.ClaudePort.Connection.PortSpawn do
  @behaviour El.ClaudePort.Behaviours.PortSpawn

  def spawn({:error, reason}, _state), do: {:error, reason}
  def spawn({:ok, {executable, args}}, state) do
    find_and_spawn(:os.find_executable(String.to_charlist(executable)), executable, args, state)
  end

  defp find_and_spawn(false, executable, _args, _state) do
    {:error, "CLI executable not found: #{executable}"}
  end
  defp find_and_spawn(exe_path, _executable, args, state) do
    spawn_port(exe_path, args, state.cwd, state.port_module)
  end

  defp spawn_port(exe_path, args, cwd, port_module) do
    port_module.open({:spawn_executable, exe_path}, port_opts(args, cwd))
  end

  defp port_opts(args, cwd) do
    named_opts(args, cwd) ++ port_flags()
  end

  defp named_opts(args, cwd) do
    [
      {:args, args},
      {:cd, String.to_charlist(cwd)},
      {:env, env_charlist()}
    ]
  end

  defp port_flags, do: [:binary, :exit_status, :stderr_to_stdout]

  defp env_charlist do
    Enum.map(env_module().get(), &charlist_pair/1)
  end

  defp charlist_pair({k, v}) do
    {String.to_charlist(k), String.to_charlist(v)}
  end

  defp env_module, do: Application.get_env(:el, :env_module, El.Infra.Env)
end
