defmodule El.Features.OnOffSpec do
  use ExUnit.Case, async: false

  import Mox
  setup :verify_on_exit!

  describe "El.start/2" do
    test "calls DynamicSupervisor.start_child with El.Session" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :dude -> [] end)
      spec = %{
        id: :dude,
        start: {El.Session.Api, :start_link, [{:dude, []}]},
        restart: :temporary
      }

      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor, ^spec ->
        {:ok, :mock_pid}
      end)

      El.start(:dude)
    end

    test "passes options through to El.Session" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :dude -> [] end)
      spec = %{
        id: :dude,
        start: {El.Session.Api, :start_link, [{:dude, [claude_module: TestClaudeCode]}]},
        restart: :temporary
      }

      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor, ^spec ->
        {:ok, :mock_pid}
      end)

      El.start(:dude, claude_module: TestClaudeCode)
    end

    test "returns session name on success" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :dude -> [] end)
      stub_fn = fn El.SessionSupervisor, _ -> {:ok, :mock_pid} end
      stub(El.MockSupervisor, :start_child, stub_fn)
      assert El.start(:dude) == :dude
    end

    test "returns name if session already registered" do
      lookup_fn = fn El.Registry, :dude -> [{:existing_pid, :registered}] end
      expect(El.MockRegistry, :lookup, lookup_fn)
      assert El.start(:dude) == :dude
    end
  end

  describe "El.exit/1" do
    test "looks up session in registry" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :dude -> [] end)
      stub(El.MockApp, :delete_session_messages, fn _ -> :ok end)
      El.exit(:dude)
    end

    test "terminates child when session found" do
      lookup_fn = fn El.Registry, :dude -> [{:mock_pid, :meta}] end
      expect(El.MockRegistry, :lookup, lookup_fn)
      term_fn = fn El.SessionSupervisor, :mock_pid -> :ok end
      stub(El.MockSupervisor, :terminate_child, term_fn)
      stub(El.MockMonitor, :wait_for_down, fn _, _ -> :ok end)
      El.exit(:dude)
    end

    test "monitors process and waits for DOWN" do
      lookup_fn = fn El.Registry, :dude -> [{:mock_pid, :meta}] end
      expect(El.MockRegistry, :lookup, lookup_fn)
      stub_fn = fn El.SessionSupervisor, _pid -> :ok end
      stub(El.MockSupervisor, :terminate_child, stub_fn)
      stub(El.MockMonitor, :wait_for_down, fn _ref, :dude -> :ok end)
      El.exit(:dude)
    end
  end

  describe "El.ls/0" do
    test "calls Registry.select to list all sessions" do
      select_fn = fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:dude, :duder, :dudito]
      end

      expect(El.MockRegistry, :select, select_fn)
      sessions = El.ls()
      assert sessions == [:dude, :duder, :dudito]
    end

    test "returns sorted list" do
      select_fn = fn El.Registry, _ -> [:dudito, :dude, :duder] end
      expect(El.MockRegistry, :select, select_fn)
      sessions = El.ls()
      assert sessions == [:dude, :duder, :dudito]
    end

    test "returns empty list when no sessions" do
      expect(El.MockRegistry, :select, fn El.Registry, _ -> [] end)
      sessions = El.ls()
      assert sessions == []
    end
  end
end
