defmodule El.ClaudeCode do
  @default_session_module ClaudeCode.Session

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
    |> add_resume_if_present(opts)
  end

  defp extract_session_module(nil) do
    @default_session_module
  end

  defp extract_session_module(module) do
    module
  end

  defp base_session_opts(session_id, cli_path) do
    [
      adapter: {ClaudeCode.Adapter.Port, [cli_path: cli_path]},
      session_id: session_id,
      dangerously_skip_permissions: true
    ]
  end

  defp add_model(session_opts, nil) do
    session_opts
  end

  defp add_model(session_opts, model) do
    session_opts ++ [model: model]
  end

  defp extract_session_id(opts) do
    Keyword.pop(opts, :session_id)
  end

  defp add_resume_if_present(session_opts, opts) do
    add_resume(session_opts, Keyword.get(opts, :resume))
  end

  defp add_resume(session_opts, nil) do
    session_opts
  end

  defp add_resume(session_opts, sid) do
    session_opts ++ [resume: sid]
  end

  def stream(pid, prompt) do
    ClaudeCode.Session.stream(pid, prompt)
  end
end
