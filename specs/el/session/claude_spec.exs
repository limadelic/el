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
    test "returns tuple with model captured from Init event" do
      assert {"test result", "test-model"} = El.Session.Claude.ask(:test_pid, "test")
    end

    test "returns error tuple and nil model when pid is nil" do
      assert {"(ClaudeCode unavailable)", nil} = El.Session.Claude.ask(nil, "test")
    end
  end
end
