defmodule El.Session.Store.Spec do
  use ExUnit.Case

  setup_all do
    Code.ensure_loaded!(El.Session.Store)
    :ok
  end

  describe "El.Session.Store.replace_ask/5" do
    test "empty list returns empty list" do
      result = El.Session.Store.replace_ask([], make_ref(), "message", "response")
      assert result == [{"ask", "message", "response", %{}}]
    end

    test "single pending entry with matching ref is replaced with response" do
      ref = make_ref()
      pending = {"ask", "message", "", %{ref: ref}}
      messages = [pending]

      result = El.Session.Store.replace_ask(messages, ref, "message", "response")

      assert result == [{"ask", "message", "response", %{}}]
    end

    test "multiple pending entries, only matching ref replaced, others untouched" do
      ref1 = make_ref()
      ref2 = make_ref()
      ref3 = make_ref()

      messages = [
        {"ask", "msg1", "", %{ref: ref1}},
        {"ask", "msg2", "", %{ref: ref2}},
        {"ask", "msg3", "", %{ref: ref3}}
      ]

      result = El.Session.Store.replace_ask(messages, ref2, "msg2", "response2")

      assert result == [
        {"ask", "msg1", "", %{ref: ref1}},
        {"ask", "msg2", "response2", %{}},
        {"ask", "msg3", "", %{ref: ref3}}
      ]
    end

    test "no matching entry appends new entry at end" do
      ref1 = make_ref()
      ref2 = make_ref()

      messages = [
        {"ask", "msg1", "", %{ref: ref1}}
      ]

      result = El.Session.Store.replace_ask(messages, ref2, "msg2", "response2")

      assert result == [
        {"ask", "msg1", "", %{ref: ref1}},
        {"ask", "msg2", "response2", %{}}
      ]
    end

    test "with model parameter includes model in metadata" do
      ref = make_ref()
      pending = {"ask", "message", "", %{ref: ref}}
      messages = [pending]

      result = El.Session.Store.replace_ask(messages, ref, "message", "response", "claude-3")

      assert result == [{"ask", "message", "response", %{model: "claude-3"}}]
    end

    test "with nil model uses empty metadata" do
      ref = make_ref()
      pending = {"ask", "message", "", %{ref: ref}}
      messages = [pending]

      result = El.Session.Store.replace_ask(messages, ref, "message", "response", nil)

      assert result == [{"ask", "message", "response", %{}}]
    end

    test "mixed message types only replaces ask with matching ref" do
      ref1 = make_ref()
      ref2 = make_ref()

      messages = [
        {"tell", "msg1", "", %{ref: ref1}},
        {"ask", "msg2", "", %{ref: ref2}},
        {"relay", "msg3", "response3", %{}}
      ]

      result = El.Session.Store.replace_ask(messages, ref2, "msg2", "response2")

      assert result == [
        {"tell", "msg1", "", %{ref: ref1}},
        {"ask", "msg2", "response2", %{}},
        {"relay", "msg3", "response3", %{}}
      ]
    end
  end
end
