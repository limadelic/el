defmodule El.SleeperImpl.Spec do
  use ExUnit.Case

  describe "El.SleeperImpl.sleep/1" do
    test "delegates to :timer.sleep and returns :ok" do
      start = System.monotonic_time(:millisecond)
      result = El.SleeperImpl.sleep(1)
      finish = System.monotonic_time(:millisecond)

      assert result == :ok
      assert finish - start >= 1
    end
  end
end
