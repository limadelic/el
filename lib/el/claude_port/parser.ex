defmodule El.ClaudePort.Parser do
  def normalize_keys(json), do: ClaudeCode.CLI.Parser.normalize_keys(json)

  def try_extract_result(buffer, session_id) do
    apply_extraction(line_extractor().extract_all_lines(buffer, []), session_id)
  end

  defp apply_extraction({[], _remaining}, _session_id), do: :incomplete
  defp apply_extraction({lines, remaining}, session_id) do
    apply_process_result(process_lines(lines, {nil, nil, nil}, session_id), remaining, session_id)
  end

  defp apply_process_result(:incomplete, _remaining, _session_id), do: :incomplete
  defp apply_process_result({:complete, result, model, sid}, remaining, session_id) do
    {:ok, result_module().finalize(result, model, sid, session_id), remaining}
  end

  defp process_lines([], _acc, _session_id), do: :incomplete
  defp process_lines([line | rest], acc, session_id) do
    apply_decode(json_decoder().decode(line), rest, acc, session_id)
  end

  defp apply_decode({:ok, json}, rest, acc, session_id) do
    process_decoded(json, rest, acc, session_id)
  end
  defp apply_decode({:error, _reason}, rest, acc, session_id) do
    process_lines(rest, acc, session_id)
  end

  defp process_decoded(json, rest, acc, session_id) do
    normalized = cc_parser().normalize_keys(json)
    {new_acc, complete?} = result_module().merge(normalized, acc)
    emit_or_continue(complete?, new_acc, rest, session_id)
  end

  defp emit_or_continue(true, new_acc, _rest, _session_id) do
    {new_result, new_model, new_sid} = new_acc
    {:complete, new_result, new_model, new_sid}
  end
  defp emit_or_continue(false, new_acc, rest, session_id) do
    process_lines(rest, new_acc, session_id)
  end

  defp cc_parser, do: Application.get_env(:el, :cc_parser, El.ClaudePort.Parser)
  defp json_decoder, do: Application.get_env(:el, :json_decoder, El.Infra.JSONDecoder)
  defp line_extractor, do: Application.get_env(:el, :line_extractor, El.ClaudePort.Parser.LineExtractor)
  defp result_module, do: Application.get_env(:el, :result_module, El.ClaudePort.Parser.Result)
end
