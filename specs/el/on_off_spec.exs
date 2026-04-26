defmodule El.Features.OnOffSpec do
  use ExUnit.Case

  setup do
    Mimic.copy(Registry)
    Mimic.copy(DynamicSupervisor)
    Mimic.copy(El.Session)
    :ok
  end

  describe "El.start/2" do
    test "calls DynamicSupervisor.start_child with El.Session" do
      Mimic.expect(Registry, :lookup, fn El.Registry, :dude -> [] end)

      Mimic.expect(DynamicSupervisor, :start_child, fn El.SessionSupervisor, {El.Session, {:dude, []}} ->
        {:ok, :mock_pid}
      end)

      El.start(:dude)
    end

    test "passes options through to El.Session" do
      Mimic.expect(Registry, :lookup, fn El.Registry, :dude -> [] end)

      Mimic.expect(DynamicSupervisor, :start_child, fn El.SessionSupervisor, {El.Session, {:dude, [claude_module: TestClaudeCode]}} ->
        {:ok, :mock_pid}
      end)

      El.start(:dude, claude_module: TestClaudeCode)
    end

    test "returns session name on success" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :dude -> [] end)
      Mimic.stub(DynamicSupervisor, :start_child, fn El.SessionSupervisor, _ -> {:ok, :mock_pid} end)

      assert El.start(:dude) == :dude
    end

    test "returns name if session already registered" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :dude -> [{:existing_pid, :registered}] end)

      result = El.start(:dude)
      assert result == :dude
    end
  end

  describe "El.exit/1" do
    test "looks up session in registry" do
      Mimic.expect(Registry, :lookup, fn El.Registry, :dude -> [] end)

      El.exit(:dude)
    end

    test "terminates child when session found" do
      Mimic.expect(Registry, :lookup, fn El.Registry, :dude -> [{:mock_pid, :meta}] end)

      Mimic.expect(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :mock_pid ->
        :ok
      end)

      El.exit(:dude)
    end

    test "monitors process and waits for DOWN" do
      Mimic.expect(Registry, :lookup, fn El.Registry, :dude -> [{:mock_pid, :meta}] end)
      Mimic.stub(DynamicSupervisor, :terminate_child, fn _, _ -> :ok end)

      El.exit(:dude)
    end
  end

  describe "El.ls/0" do
    test "calls Registry.select to list all sessions" do
      Mimic.expect(Registry, :select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:dude, :duder, :dudito]
      end)

      sessions = El.ls()
      assert sessions == [:dude, :duder, :dudito]
    end

    test "returns sorted list" do
      Mimic.expect(Registry, :select, fn El.Registry, _ ->
        [:dudito, :dude, :duder]
      end)

      sessions = El.ls()
      assert sessions == [:dude, :duder, :dudito]
    end

    test "returns empty list when no sessions" do
      Mimic.expect(Registry, :select, fn El.Registry, _ ->
        []
      end)

      sessions = El.ls()
      assert sessions == []
    end
  end
end
