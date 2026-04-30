defmodule El.ClaudeCode do
  @default_session_module ClaudeCode.Session
  @default_setting_sources ["user", "project", "local"]

  def start_link(opts) do
    session_module = extract_session_module(opts[:session_module])
    {session_id, remaining_opts} = extract_session_id(opts)
    build_and_start(session_module, session_id, remaining_opts, opts)
  end

  defp build_and_start(session_module, session_id, remaining_opts, opts) do
    cli_path = Application.get_env(:claude_code, :cli_path, :global)
    session_opts = base_session_opts(session_id, cli_path)
    final_opts = build_final_opts(session_opts, remaining_opts, opts)
    session_module.start_link(final_opts)
  end

  defp build_final_opts(session_opts, remaining_opts, opts) do
    session_opts
    |> add_model(remaining_opts[:model])
    |> add_agent(remaining_opts[:agent])
    |> add_resume_if_present(opts)
  end

  defp extract_session_module(nil), do: @default_session_module
  defp extract_session_module(module), do: module

  defp base_session_opts(session_id, cli_path) do
    opts = [base_adapter(cli_path), {:session_id, session_id}]
    opts ++ [base_perms(), base_settings()]
  end

  defp base_adapter(cli_path) do
    {:adapter, {ClaudeCode.Adapter.Port, [cli_path: cli_path]}}
  end

  defp base_perms, do: {:dangerously_skip_permissions, true}
  defp base_settings, do: {:setting_sources, @default_setting_sources}

  defp add_model(session_opts, nil), do: session_opts
  defp add_model(session_opts, model), do: session_opts ++ [model: model]

  defp add_agent(session_opts, nil), do: session_opts
  defp add_agent(session_opts, agent), do: session_opts ++ [agent: agent]

  defp extract_session_id(opts), do: Keyword.pop(opts, :session_id)

  defp add_resume_if_present(session_opts, opts) do
    add_resume(session_opts, Keyword.get(opts, :resume))
  end

  defp add_resume(session_opts, nil), do: session_opts
  defp add_resume(session_opts, sid), do: session_opts ++ [resume: sid]

  def stream(pid, prompt, opts \\ []) do
    session_module = extract_stream_session_module(opts[:session_module])
    session_module.stream(pid, prompt)
  end

  defp extract_stream_session_module(nil) do
    Application.get_env(:claude_code, :session_module, @default_session_module)
  end

  defp extract_stream_session_module(module), do: module
end
