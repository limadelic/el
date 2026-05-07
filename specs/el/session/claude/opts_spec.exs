defmodule El.Session.Claude.OptsSpec do
  use ExUnit.Case

  test "build/3 returns keyword list" do
    result = El.Session.Claude.Opts.build([], [], "session-123")
    assert is_list(result)
  end
end
