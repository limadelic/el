defmodule El.ClaudePort.State do
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
    %{
      port_module: Keyword.get(opts, :port_module, El.PortImpl),
      connection_module: Keyword.get(opts, :connection_module, El.ClaudePort.Connection),
      cli_resolver_module: Keyword.get(opts, :cli_resolver_module, El.ClaudePort.Connection.CliResolver),
      port_spawn_module: Keyword.get(opts, :port_spawn_module, El.ClaudePort.Connection.PortSpawn),
      closer_module: Keyword.get(opts, :closer_module, El.ClaudePort.Connection.Closer)
    }
  end

  defp cwd(nil), do: File.cwd!()
  defp cwd(path), do: path
end
