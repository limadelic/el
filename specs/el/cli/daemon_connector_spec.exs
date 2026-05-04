defmodule El.CLI.DaemonConnector.Spec do
  use ExUnit.Case

  describe "wait_for_daemon/2" do
    test "accepts sleeper as parameter" do
      Mox.expect(El.MockSleeper, :sleep, 0, fn _ -> :ok end)

      result = El.CLI.DaemonConnector.wait_for_daemon(0, El.MockSleeper)

      assert result == {:error, :timeout}
    end
  end

  describe "wait_for_daemon/1" do
    test "uses default sleeper when not provided" do
      result = El.CLI.DaemonConnector.wait_for_daemon(0)
      assert result == {:error, :timeout}
    end
  end
end
