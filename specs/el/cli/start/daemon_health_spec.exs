defmodule El.CLI.Start.DaemonHealth.Spec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "El.CLI.Start.DaemonHealth.ping_if_agent/3" do
    setup do
      stub(El.MockGroupLeader, :open_null_device, fn -> :null_device end)
      stub(El.MockGroupLeader, :get, fn -> :original_leader end)
      stub(El.MockGroupLeader, :set, fn _, _ -> true end)
      stub(El.MockGroupLeader, :close, fn _ -> :ok end)
      %{
        name: :test,
        base_deps: [session_api: El.MockSessionApi, group_leader: El.MockGroupLeader]
      }
    end

    test "is no-op when agent_atom is nil", %{name: name, base_deps: deps} do
      stub(El.MockSessionApi, :info, fn _ -> %{messages: 0} end)
      opts = [agent: nil]
      result = El.CLI.Start.DaemonHealth.ping_if_agent(name, opts, deps)
      assert result == :ok
    end

    test "is no-op when messages > 0 in opts", %{name: name, base_deps: deps} do
      stub(El.MockSessionApi, :info, fn _ -> %{messages: 5} end)
      opts = [agent: :some_agent]
      result = El.CLI.Start.DaemonHealth.ping_if_agent(name, opts, deps)
      assert result == :ok
    end

    @tag timeout: :infinity
    test "executes ping when conditions met", %{name: name, base_deps: deps} do
      expect(El.MockSessionApi, :info, fn _ -> %{messages: 0} end)
      expect(El.MockSessionApi, :ask, fn _, _ -> "test response" end)
      opts = [agent: :some_agent]
      result = El.CLI.Start.DaemonHealth.ping_if_agent(name, opts, deps)
      assert result == "test response"
    end
  end
end
