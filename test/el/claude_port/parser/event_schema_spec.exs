defmodule El.ClaudePort.Parser.EventSchemaSpec do
  use ExUnit.Case

  alias El.ClaudePort.Parser.EventSchema

  describe "is_result_message/1" do
    test "returns true for result type events" do
      assert EventSchema.is_result_message(%{"type" => "result"})
    end

    test "returns false for system events" do
      refute EventSchema.is_result_message(%{"type" => "system"})
    end

    test "returns false for empty map" do
      refute EventSchema.is_result_message(%{})
    end
  end

  describe "has_model/1" do
    test "returns true for system init events" do
      assert EventSchema.has_model(%{"type" => "system", "subtype" => "init"})
    end

    test "returns false for result events" do
      refute EventSchema.has_model(%{"type" => "result"})
    end

    test "returns false for empty map" do
      refute EventSchema.has_model(%{})
    end
  end

  describe "has_session_id/1" do
    test "returns true for system init events" do
      assert EventSchema.has_session_id(%{"type" => "system", "subtype" => "init"})
    end

    test "returns false for result events" do
      refute EventSchema.has_session_id(%{"type" => "result"})
    end

    test "returns false for empty map" do
      refute EventSchema.has_session_id(%{})
    end
  end

  describe "get_result/1" do
    test "extracts result from result type event" do
      assert EventSchema.get_result(%{"type" => "result", "result" => "data"}) == "data"
    end

    test "returns nil for result event without result key" do
      assert EventSchema.get_result(%{"type" => "result"}) == nil
    end

    test "returns nil for non-result events" do
      assert EventSchema.get_result(%{"type" => "system"}) == nil
    end
  end

  describe "get_model/1" do
    test "extracts model from system init event" do
      assert EventSchema.get_model(%{"type" => "system", "subtype" => "init", "model" => "claude-3"}) == "claude-3"
    end

    test "returns nil for result events" do
      assert EventSchema.get_model(%{"type" => "result"}) == nil
    end

    test "returns nil for empty map" do
      assert EventSchema.get_model(%{}) == nil
    end
  end

  describe "get_session_id/1" do
    test "extracts session_id from system init event" do
      assert EventSchema.get_session_id(%{"type" => "system", "subtype" => "init", "session_id" => "abc123"}) == "abc123"
    end

    test "returns nil for result events" do
      assert EventSchema.get_session_id(%{"type" => "result"}) == nil
    end

    test "returns nil for empty map" do
      assert EventSchema.get_session_id(%{}) == nil
    end
  end
end
