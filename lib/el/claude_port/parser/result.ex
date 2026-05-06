defmodule El.ClaudePort.Parser.Result do
  alias El.ClaudePort.Parser.EventSchema

  @behaviour El.Behaviours.ParserResult

  def merge(normalized, acc) do
    {build_acc(normalized, acc), EventSchema.is_result_message(normalized)}
  end

  defp build_acc(normalized, {result, model, sid}) do
    {
      pick_result(EventSchema.is_result_message(normalized), normalized, result),
      pick_model(EventSchema.has_model(normalized), normalized, model),
      pick_sid(EventSchema.has_session_id(normalized), normalized, sid)
    }
  end

  defp pick_result(true, normalized, _result), do: EventSchema.get_result(normalized)
  defp pick_result(false, _normalized, result), do: result

  defp pick_model(true, normalized, _model), do: EventSchema.get_model(normalized)
  defp pick_model(false, _normalized, model), do: model

  defp pick_sid(true, normalized, _sid), do: EventSchema.get_session_id(normalized)
  defp pick_sid(false, _normalized, sid), do: sid
end
