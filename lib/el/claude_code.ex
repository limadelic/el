defmodule El.ClaudeCode do
  @default_session_module ClaudeCode.Session

  def start_link(opts) do
    session_module = get_session_module(opts)
    cli_path = Application.get_env(:claude_code, :cli_path, :global)

    {session_id, remaining_opts} = extract_session_id_or_generate(opts)
    session_opts = base_session_opts(session_id, cli_path)
    final_opts = add_model_if_present(session_opts, remaining_opts)
    final_opts = add_resume_if_present(final_opts, opts)
    session_module.start_link(final_opts)
  end

  defp get_session_module(opts) do
    extract_session_module(opts[:session_module])
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

  defp add_model_if_present(session_opts, opts) do
    add_model(session_opts, opts[:model])
  end

  defp add_model(session_opts, nil) do
    session_opts
  end

  defp add_model(session_opts, model) do
    session_opts ++ [model: model]
  end

  defp extract_session_id_or_generate(opts) do
    case Keyword.pop(opts, :resume) do
      {nil, remaining_opts} ->
        {random_uuid(), remaining_opts}

      {session_id, remaining_opts} ->
        {session_id, remaining_opts}
    end
  end

  defp add_resume_if_present(session_opts, opts) do
    case Keyword.get(opts, :resume) do
      nil -> session_opts
      session_id -> session_opts ++ [resume: session_id]
    end
  end

  def stream(pid, prompt) do
    ClaudeCode.Session.stream(pid, prompt)
  end

  defp random_uuid do
    bytes = :crypto.strong_rand_bytes(16)
    hex = Base.encode16(bytes, case: :lower)

    "#{String.slice(hex, 0, 8)}-#{String.slice(hex, 8, 4)}-#{String.slice(hex, 12, 4)}-#{String.slice(hex, 16, 4)}-#{String.slice(hex, 20, 12)}"
  end
end
