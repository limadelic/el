defmodule El.Session.Commands.AskSpec do
  use ExUnit.Case

  alias El.Session.Commands.Ask
  alias El.Session.State

  defmodule MockMessageStore do
    def insert(_name, _entry), do: :ok
    def delete_entry(_name, _entry), do: :ok
    def lookup(_name), do: []
    def delete(_name), do: :ok
  end

  describe "finalize_ask with quiet probe on non-agent path" do
    test "filters out 'who are you?' message from state" do
      state = setup_state()

      ask = %{
        from: self(),
        ref: make_ref(),
        message: "who are you?",
        response: "I am Claude",
        model: "claude-3"
      }

      finalized = Ask.finalize_ask(state, ask)

      assert finalized.messages == []
    end

    test "filters out 'who are you?' message but preserves session_id" do
      session_id = "test-session-123"
      state = setup_state()

      ask = %{
        from: self(),
        ref: make_ref(),
        message: "who are you?",
        response: "I am Claude",
        model: "claude-3"
      }

      finalized = Ask.finalize_ask(state, ask)

      assert length(finalized.messages) == 0
      assert finalized.session_id == session_id
    end

    test "preserves regular ask messages in state" do
      state = setup_state()

      ask = %{
        from: self(),
        ref: make_ref(),
        message: "what is 2+2?",
        response: "4",
        model: "claude-3"
      }

      finalized = Ask.finalize_ask(state, ask)

      assert length(finalized.messages) == 1
      assert finalized.messages == [{"ask", "what is 2+2?", "4", %{model: "claude-3"}}]
    end
  end

  defp setup_state do
    State.build(
      :test_session,
      [message_store: MockMessageStore],
      [],
      "test-session-123",
      "/tmp"
    )
  end
end
