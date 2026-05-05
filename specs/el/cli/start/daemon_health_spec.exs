defmodule El.CLI.Start.DaemonHealth.Spec do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  describe "El.CLI.Start.DaemonHealth.ping_if_agent/3" do
    test "is no-op when agent_atom is nil" do
      Mox.expect(El.MockSessionApi, :info, fn _ -> %{messages: 0} end)
      opts = [agent: nil]
      deps = [session_api: El.MockSessionApi]
      result = El.CLI.Start.DaemonHealth.ping_if_agent(:test, opts, deps)
      assert result == :ok
    end

    test "is no-op when messages > 0 in opts" do
      Mox.expect(El.MockSessionApi, :info, fn _ -> %{messages: 5} end)
      opts = [agent: :some_agent]
      deps = [session_api: El.MockSessionApi]
      result = El.CLI.Start.DaemonHealth.ping_if_agent(:test, opts, deps)
      assert result == :ok
    end

    @tag timeout: :infinity
    test "executes ping when conditions met" do
      Mox.expect(El.MockSessionApi, :info, fn _ -> %{messages: 0} end)
      Mox.expect(El.MockSessionApi, :ask, fn _, _ -> "test response" end)
      Mox.expect(El.MockGroupLeader, :open_null_device, fn -> :null_device end)
      Mox.expect(El.MockGroupLeader, :get, fn -> :original_leader end)
      Mox.expect(El.MockGroupLeader, :set, fn _, _ -> true end)
      Mox.expect(El.MockGroupLeader, :set, fn _, _ -> true end)
      Mox.expect(El.MockGroupLeader, :close, fn _ -> :ok end)
      opts = [agent: :some_agent]
      deps = [session_api: El.MockSessionApi, group_leader: El.MockGroupLeader]
      result = El.CLI.Start.DaemonHealth.ping_if_agent(:test, opts, deps)
      assert result == "test response"
    end
  end
end
