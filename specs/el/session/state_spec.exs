defmodule El.Session.StateSpec do
  use ExUnit.Case

  test "build/5 returns a map" do
    result = El.Session.State.build(:test, [], [], "session-123", "/tmp")
    assert is_map(result)
  end

  test "build/5 puts name in result" do
    result = El.Session.State.build(:test, [], [], "session-123", "/tmp")
    assert result[:name] == :test
  end
end
