defmodule El.ClaudePort.Parser do
  require Logger

  def try_extract_result(buffer, session_id) do
    apply_extraction(extract_all_lines(buffer, []), session_id)
  end

  defp apply_extraction({[], _remaining}, _session_id), do: :incomplete
  defp apply_extraction({lines, remaining}, session_id) do
    apply_process_result(process_lines(lines, {nil, nil, nil}, session_id), remaining, session_id)
  end

  defp apply_process_result(:incomplete, _remaining, _session_id), do: :incomplete
  defp apply_process_result({:complete, result, model, sid}, remaining, session_id) do
    {:ok, {nil_to_empty(result), model, resolve_sid(sid, session_id)}, remaining}
  end

  defp resolve_sid(nil, fallback), do: fallback
  defp resolve_sid(sid, _fallback), do: sid

  defp extract_all_lines(buffer, acc) do
    apply_extracted_line(extract_one_line(buffer), buffer, acc)
  end

  defp apply_extracted_line({nil, _}, buffer, acc), do: {Enum.reverse(acc), buffer}
  defp apply_extracted_line({line, remaining}, _buffer, acc), do: extract_all_lines(remaining, [line | acc])

  defp extract_one_line(buffer) do
    apply_split(String.split(buffer, "\n", parts: 2), buffer)
  end

  defp apply_split([line, rest], _buffer), do: {line, rest}
  defp apply_split([_incomplete], buffer), do: {nil, buffer}
  defp apply_split([], _buffer), do: {nil, ""}

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
    {new_acc, complete?} = merge_line(normalized, acc)
    emit_or_continue(complete?, new_acc, rest, session_id)
  end

  defp emit_or_continue(true, new_acc, _rest, _session_id) do
    {new_result, new_model, new_sid} = new_acc
    {:complete, new_result, new_model, new_sid}
  end
  defp emit_or_continue(false, new_acc, rest, session_id) do
    process_lines(rest, new_acc, session_id)
  end

  defp merge_line(normalized, acc) do
    {build_acc(normalized, acc), is_result_message(normalized)}
  end

  defp build_acc(normalized, {result, model, sid}) do
    {
      pick_result(is_result_message(normalized), normalized, result),
      pick_model(has_model(normalized), normalized, model),
      pick_sid(has_session_id(normalized), normalized, sid)
    }
  end

  defp pick_result(true, normalized, _result), do: get_result(normalized)
  defp pick_result(false, _normalized, result), do: result

  defp pick_model(true, normalized, _model), do: get_model(normalized)
  defp pick_model(false, _normalized, model), do: model

  defp pick_sid(true, normalized, _sid), do: get_session_id(normalized)
  defp pick_sid(false, _normalized, sid), do: sid

  defp is_result_message(%{"type" => "result"}), do: true
  defp is_result_message(_), do: false

  defp has_model(%{"type" => "system", "subtype" => "init"}), do: true
  defp has_model(_), do: false

  defp has_session_id(%{"type" => "system", "subtype" => "init"}), do: true
  defp has_session_id(_), do: false

  defp get_result(%{"type" => "result", "result" => result}), do: result
  defp get_result(%{"type" => "result"} = event) do
    Logger.debug("ClaudePort found result event but no 'result' key: #{inspect(event)}")
    nil
  end
  defp get_result(_), do: nil

  defp get_model(%{"type" => "system", "subtype" => "init", "model" => model}), do: model
  defp get_model(_), do: nil

  defp get_session_id(%{"type" => "system", "subtype" => "init", "session_id" => session_id}), do: session_id
  defp get_session_id(_), do: nil

  defp nil_to_empty(nil), do: ""
  defp nil_to_empty(result), do: result

  defp cc_parser, do: Application.get_env(:el, :cc_parser, El.CCParser)
  defp json_decoder, do: Application.get_env(:el, :json_decoder, El.JSONDecoder)
end
