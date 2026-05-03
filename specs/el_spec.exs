defmodule El.Spec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "start/2" do
    test "returns :created when lookup returns empty" do
      expect(El.MockRegistry, :lookup, fn El.Registry, _name ->
        []
      end)

      stub(El.MockSupervisor, :start_child, fn El.SessionSupervisor, _args ->
        {:ok, :pid}
      end)

      assert El.start(:kent) == :created
    end

    test "returns :already_running when session already exists" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :lisa ->
        [{:pid, :meta}]
      end)

      assert El.start(:lisa) == :already_running
    end

    test "passes options to supervisor" do
      expect(El.MockRegistry, :lookup, fn El.Registry, _name -> [] end)

      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor,
                                                 {El.Session, {:eric, opts}} ->
        assert opts == [claude_module: MockModule]
        {:ok, :pid}
      end)

      El.start(:eric, claude_module: MockModule)
    end
  end

  describe "tell/2" do
    test "delegates to El.Session.Api.tell" do
      expect(El.MockSessionApi, :tell, fn :kent, "message" -> :ok end)
      assert El.tell(:kent, "message") == :ok
    end
  end

  describe "tell_ask/3" do
    test "delegates to El.Session.Api.tell_ask" do
      expect(El.MockSessionApi, :tell_ask, fn :kent, :lisa, "message" -> :ok end)
      assert El.tell_ask(:kent, :lisa, "message") == :ok
    end
  end

  describe "clear/1" do
    test "delegates to El.Session.Api.clear" do
      expect(El.MockSessionApi, :clear, fn :kent -> :ok end)
      assert El.clear(:kent) == :ok
    end
  end

  describe "agent/1" do
    test "delegates to El.Session.Api.agent" do
      expect(El.MockSessionApi, :agent, fn :kent -> "kent" end)
      assert El.agent(:kent) == "kent"
    end
  end

  describe "exit/1" do
    test "returns ok when session found and terminated" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :kent ->
        [{:pid, :meta}]
      end)

      terminate_stub = fn El.SessionSupervisor, :pid -> :ok end
      stub(El.MockSupervisor, :terminate_child, terminate_stub)
      stub(El.MockMonitor, :wait_for_down, fn _ref, _name -> :ok end)
      result = El.exit(:kent)
      assert result == :ok
    end

    test "deletes session messages when session not found" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :kent -> [] end)
      expect(El.MockApp, :delete_session_messages, fn :kent -> :ok end)
      El.exit(:kent)
    end

    test "returns not_found when session not running" do
      expect(El.MockRegistry, :lookup, fn El.Registry, :unknown -> [] end)
      stub(El.MockApp, :delete_session_messages, fn :unknown -> :ok end)
      assert El.exit(:unknown) == :not_found
    end

    test "handles errors during termination and returns ok" do
      expect(El.MockRegistry, :lookup, fn El.Registry, _name ->
        [{:pid, :meta}]
      end)

      stub(El.MockSupervisor, :terminate_child, fn _, _ ->
        raise "error"
      end)

      stub(El.MockMonitor, :wait_for_down, fn _, _ -> :ok end)
      result = El.exit(:kent)
      assert result == :ok
    end
  end

  describe "exit/1 with :all" do
    test "terminates all sessions" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:kent, :lisa]
      end)

      expect(El.MockRegistry, :lookup, fn El.Registry, :kent ->
        [{:pid1, :meta}]
      end)

      expect(El.MockRegistry, :lookup, fn El.Registry, :lisa ->
        [{:pid2, :meta}]
      end)

      terminate_stub = fn El.SessionSupervisor, _pid -> :ok end
      stub(El.MockSupervisor, :terminate_child, terminate_stub)
      stub(El.MockMonitor, :wait_for_down, fn _ref, _name -> :ok end)
      El.exit(:all)
    end
  end

  describe "exit_pattern/1" do
    test "exits sessions matching glob pattern" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:dude1, :dude2, :lisa]
      end)

      expect(El.MockRegistry, :lookup, fn El.Registry, :dude1 ->
        [{:pid1, :meta}]
      end)

      expect(El.MockRegistry, :lookup, fn El.Registry, :dude2 ->
        [{:pid2, :meta}]
      end)

      terminate_stub = fn El.SessionSupervisor, _pid -> :ok end
      stub(El.MockSupervisor, :terminate_child, terminate_stub)
      stub(El.MockMonitor, :wait_for_down, fn _ref, _name -> :ok end)
      El.exit_pattern("dude*")
    end

    test "exits no sessions when pattern matches nothing" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:alice, :bob]
      end)

      result = El.exit_pattern("charlie*")
      assert result == :ok
    end
  end

  describe "clear_pattern/1" do
    test "clears sessions matching glob pattern" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:dude1, :dude2, :lisa]
      end)

      expect(El.MockSession, :clear, fn :dude1 -> :ok end)
      expect(El.MockSession, :clear, fn :dude2 -> :ok end)
      El.clear_pattern("dude*")
    end

    test "clears no sessions when pattern matches nothing" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:alice, :bob]
      end)

      result = El.clear_pattern("charlie*")
      assert result == :ok
    end
  end

  describe "log_pattern/2" do
    test "returns logs from sessions matching glob pattern" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:dude1, :dude2, :lisa]
      end)

      expect(El.MockSession, :log, fn :dude1, 1 ->
        [{"ask", "hi", "reply", %{}}]
      end)

      expect(El.MockSession, :log, fn :dude2, 1 ->
        [{"tell", "hello", "world", %{}}]
      end)

      result = El.log_pattern("dude*", 1)
      assert length(result) == 2
    end

    test "returns empty list when pattern matches nothing" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:alice, :bob]
      end)

      result = El.log_pattern("charlie*", 1)
      assert result == []
    end

    test "skips sessions with :not_found" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:dude1]
      end)

      expect(El.MockSession, :log, fn :dude1, 1 -> :not_found end)
      result = El.log_pattern("dude*", 1)
      assert result == []
    end
  end

  describe "ls/0" do
    test "returns sorted list with message counts" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern ->
        [:zeta, :alpha, :beta]
      end)

      expect(El.MockSession, :info, fn :zeta -> %{messages: 3} end)
      expect(El.MockSession, :info, fn :alpha -> %{messages: 1} end)
      expect(El.MockSession, :info, fn :beta -> %{messages: 0} end)

      result = El.ls()
      assert result == [{:alpha, 1}, {:beta, 0}, {:zeta, 3}]
    end

    test "returns empty list when no sessions" do
      expect(El.MockRegistry, :select, fn El.Registry, _pattern -> [] end)
      assert El.ls() == []
    end
  end

  describe "session_info/1" do
    test "returns message count for session" do
      expect(El.MockSession, :info, fn :kent -> %{messages: 5} end)
      result = El.session_info(:kent)
      assert result == %{messages: 5}
    end
  end
end
