defmodule El.ClaudePort.State do
  @seam_defaults [
    port_module: El.Infra.Port,
    connection_module: El.ClaudePort.Connection,
    cli_resolver_module: El.ClaudePort.Connection.CliResolver,
    port_spawn_module: El.ClaudePort.Connection.PortSpawn,
    closer_module: El.ClaudePort.Connection.Closer
  ]

  def build(opts) do
    Map.merge(runtime_state(), opts_state(opts))
  end

  defp runtime_state do
    %{port: nil, buffer: "", current_request_id: nil, responses: []}
  end

  defp opts_state(opts) do
    Map.merge(opts_ids(opts), opts_env(opts))
  end

  defp opts_ids(opts) do
    %{
      session_id: Keyword.get(opts, :session_id),
      resume_id: Keyword.get(opts, :resume),
      opts: opts
    }
  end

  defp opts_env(opts) do
    Map.merge(%{
      cwd: cwd(Keyword.get(opts, :cwd)),
      cli_path: Keyword.get(opts, :cli_path, :global)
    }, module_seams(opts))
  end

  defp module_seams(opts) do
    Map.new(@seam_defaults, fn {k, d} -> {k, Keyword.get(opts, k, d)} end)
  end

  defp cwd(nil), do: fs_module().cwd!()
  defp cwd(path), do: path

  defp fs_module, do: Application.get_env(:el, :fs_module, El.Infra.FileSystem)
end
