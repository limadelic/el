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
    %{
      cwd: cwd(Keyword.get(opts, :cwd)),
      cli_path: Keyword.get(opts, :cli_path, :global),
      port_module: Keyword.get(opts, :port_module, El.PortImpl)
    }
  end

  defp cwd(nil), do: File.cwd!()
  defp cwd(path), do: path
end
