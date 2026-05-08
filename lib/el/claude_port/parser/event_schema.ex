defmodule El.ClaudePort.Parser.EventSchema do
  @behaviour El.ClaudePort.Behaviours.ParserExtract.EventSchema
  require Logger

  def is_result_message(%{"type" => "result"}), do: true
  def is_result_message(_), do: false

  def has_model(%{"type" => "system", "subtype" => "init"}), do: true
  def has_model(_), do: false

  def has_session_id(%{"type" => "system", "subtype" => "init"}), do: true
  def has_session_id(_), do: false

  def get_result(%{"type" => "result", "result" => result}), do: result
  def get_result(%{"type" => "result"} = event) do
    Logger.debug("ClaudePort found result event but no 'result' key: #{inspect(event)}")
    nil
  end
  def get_result(_), do: nil

  def get_model(%{"type" => "system", "subtype" => "init", "model" => model}), do: model
  def get_model(_), do: nil

  def get_session_id(%{"type" => "system", "subtype" => "init", "session_id" => session_id}), do: session_id
  def get_session_id(_), do: nil
end
