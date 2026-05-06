defmodule El.Session.StateSpec do
  use ExUnit.Case

  test "build/5 returns a map with :name key" do
    result = El.Session.State.build(:test, [], [], "session-123", "/tmp")
    assert is_map(result)
    assert result[:name] == :test
  end
end
