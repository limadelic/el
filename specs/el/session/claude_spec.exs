defmodule El.Session.Claude.Spec do
  use ExUnit.Case

  setup do
    Application.put_env(:claude_code, :session_module, MockClaudeCodeSession)

    on_exit(fn ->
      Application.delete_env(:claude_code, :session_module)
    end)

    :ok
  end

  describe "resume_options/2" do
    test "adds :resume to opts with session_id" do
      assert [resume: "session-123", session_id: "session-123"] =
        El.Session.Claude.resume_options([], "session-123")
    end
  end

  describe "ask/2" do
    test "returns result from ask" do
      assert {"test result", _, _} = El.Session.Claude.ask(:test_pid, "test")
    end

    test "captures model from Init event" do
      assert {_, "test-model", _} = El.Session.Claude.ask(:test_pid, "test")
    end

    test "captures session_id from Init event" do
      assert {_, _, "test-session-id"} = El.Session.Claude.ask(:test_pid, "test")
    end

    test "returns error tuple with nils when pid is nil" do
      assert {"(ClaudeCode unavailable)", nil, nil} = El.Session.Claude.ask(nil, "test")
    end
  end
end
