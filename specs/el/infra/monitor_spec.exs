defmodule El.Infra.MonitorSpec do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!

  describe "wait_for_down/3" do
    test "calls app.delete_session_messages(name, opts) when :DOWN arrives" do
      expect(El.MockSessionDeletion, :delete_session_messages, fn :test_session, _opts -> :ok end)

      ref = Process.monitor(self())
      send(self(), {:DOWN, ref, :process, self(), :normal})

      result = El.Infra.Monitor.wait_for_down(ref, :test_session, app: El.MockSessionDeletion)

      assert result == :ok
    end

    test "calls app.delete_session_messages(name, opts) after timeout" do
      expect(El.MockSessionDeletion, :delete_session_messages, fn :test_session, _opts -> :ok end)

      ref = Process.monitor(self())

      result = El.Infra.Monitor.wait_for_down(ref, :test_session, app: El.MockSessionDeletion, timeout: 0)

      assert result == :ok
    end
  end
end
