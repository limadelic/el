defmodule El.Session.ClaudeOptsSpec do
  use ExUnit.Case

  test "build/3 returns keyword list" do
    result = El.Session.ClaudeOpts.build([], [], "session-123")
    assert is_list(result)
  end
end
