defmodule El.ClaudePort.Connection.CliResolver do
  @behaviour El.ClaudePort.Behaviours.CliResolver

  alias ClaudeCode.CLI.Command
  alias ClaudeCode.Adapter.Port.Resolver
  alias ClaudeCode.Adapter.Port.Installer

  def resolve(_cli_path, opts, resume_id) do
    streaming_opts = Keyword.put(opts, :input_format, :stream_json)
    apply_find_binary(Resolver.find_binary(streaming_opts), streaming_opts, resume_id)
  end

  defp apply_find_binary({:ok, executable}, streaming_opts, resume_id) do
    args = Command.build_args("", streaming_opts, resume_id)
    {:ok, {executable, List.delete_at(args, -1)}}
  end

  defp apply_find_binary({:error, :not_found}, _streaming_opts, _resume_id) do
    {:error, {:cli_not_found, Installer.cli_not_found_message()}}
  end

  defp apply_find_binary({:error, reason}, _streaming_opts, _resume_id) do
    {:error, {:cli_resolution_failed, reason}}
  end
end
