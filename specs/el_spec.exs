defmodule El.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(Registry)
    Mimic.copy(DynamicSupervisor)
    Mimic.copy(El.Session)
    Mimic.copy(El.Application)
    :ok
  end

  describe "start/2" do
    test "returns name when lookup returns empty" do
      Mimic.stub(Registry, :lookup, fn El.Registry, _name -> [] end)
      Mimic.stub(DynamicSupervisor, :start_child, fn El.SessionSupervisor, _args -> {:ok, :pid} end)

      assert El.start(:kent) == :kent
    end

    test "returns name when session already exists" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :lisa -> [{:pid, :meta}] end)

      assert El.start(:lisa) == :lisa
    end

    test "passes options to supervisor" do
      opts = [claude_module: MockModule]
      Mimic.stub(Registry, :lookup, fn El.Registry, _name -> [] end)
      Mimic.expect(DynamicSupervisor, :start_child, fn El.SessionSupervisor, {El.Session, {_name, passed_opts}} ->
        assert passed_opts == opts
        {:ok, :pid}
      end)

      El.start(:eric, opts)
    end
  end

  describe "tell/2" do
    test "delegates to El.Session.tell" do
      Mimic.expect(El.Session, :tell, fn :kent, "message" -> :ok end)

      assert El.tell(:kent, "message") == :ok
    end
  end

  describe "tell_ask/3" do
    test "delegates to El.Session.tell_ask" do
      Mimic.expect(El.Session, :tell_ask, fn :kent, :lisa, "message" -> :ok end)

      assert El.tell_ask(:kent, :lisa, "message") == :ok
    end
  end

  describe "clear/1" do
    test "delegates to El.Session.clear" do
      Mimic.expect(El.Session, :clear, fn :kent -> :ok end)

      assert El.clear(:kent) == :ok
    end
  end

  describe "exit/1" do
    test "returns ok when session found and terminated" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :kent -> [{:pid, :meta}] end)
      Mimic.expect(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :pid -> :ok end)
      Mimic.stub(El.Application, :delete_session_messages, fn :kent -> :ok end)

      result = El.exit(:kent)
      assert result == :ok
    end

    test "deletes session messages on successful termination" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :kent -> [{:pid, :meta}] end)
      Mimic.stub(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :pid -> :ok end)
      Mimic.expect(El.Application, :delete_session_messages, fn :kent -> :ok end)

      El.exit(:kent)
      Mimic.verify!(El.Application)
    end

    test "returns not_found when session not running" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :unknown -> [] end)

      assert El.exit(:unknown) == :not_found
    end

    test "rescues errors and returns ok" do
      Mimic.stub(Registry, :lookup, fn El.Registry, _name -> [{:pid, :meta}] end)
      Mimic.stub(DynamicSupervisor, :terminate_child, fn _, _ -> raise "error" end)
      Mimic.stub(El.Application, :delete_session_messages, fn _name -> :ok end)

      result = El.exit(:kent)
      assert result == :ok
    end
  end

  describe "exit/1 with :all" do
    test "terminates all sessions" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:kent, :lisa] end)
      Mimic.stub(Registry, :lookup, fn
        El.Registry, :kent -> [{:pid1, :meta}]
        El.Registry, :lisa -> [{:pid2, :meta}]
      end)
      Mimic.expect(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :pid1 -> :ok end)
      Mimic.expect(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :pid2 -> :ok end)
      Mimic.expect(El.Application, :delete_session_messages, fn :kent -> :ok end)
      Mimic.expect(El.Application, :delete_session_messages, fn :lisa -> :ok end)

      El.exit(:all)
      Mimic.verify!()
    end
  end

  describe "exit_pattern/1" do
    test "exits sessions matching glob pattern" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:dude1, :dude2, :lisa] end)
      Mimic.stub(Registry, :lookup, fn
        El.Registry, :dude1 -> [{:pid1, :meta}]
        El.Registry, :dude2 -> [{:pid2, :meta}]
      end)
      Mimic.expect(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :pid1 -> :ok end)
      Mimic.expect(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :pid2 -> :ok end)
      Mimic.expect(El.Application, :delete_session_messages, fn :dude1 -> :ok end)
      Mimic.expect(El.Application, :delete_session_messages, fn :dude2 -> :ok end)

      El.exit_pattern("dude*")
      Mimic.verify!()
    end

    test "exits no sessions when pattern matches nothing" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:alice, :bob] end)

      result = El.exit_pattern("charlie*")
      assert result == :ok
    end
  end

  describe "clear_pattern/1" do
    test "clears sessions matching glob pattern" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:dude1, :dude2, :lisa] end)
      Mimic.expect(El.Session, :clear, fn :dude1 -> :ok end)
      Mimic.expect(El.Session, :clear, fn :dude2 -> :ok end)

      El.clear_pattern("dude*")
      Mimic.verify!()
    end

    test "clears no sessions when pattern matches nothing" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:alice, :bob] end)

      result = El.clear_pattern("charlie*")
      assert result == :ok
    end
  end

  describe "log_pattern/2" do
    test "returns logs from sessions matching glob pattern" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:dude1, :dude2, :lisa] end)
      Mimic.expect(El.Session, :log, fn :dude1, 1 -> [{"ask", "hi", "reply", %{}}] end)
      Mimic.expect(El.Session, :log, fn :dude2, 1 -> [{"tell", "hello", "world", %{}}] end)
      Mimic.stub(El.Session, :log, fn :lisa, 1 -> :not_found end)

      result = El.log_pattern("dude*", 1)
      assert length(result) == 2
    end

    test "returns empty list when pattern matches nothing" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:alice, :bob] end)
      Mimic.stub(El.Session, :log, fn _, 1 -> :not_found end)

      result = El.log_pattern("charlie*", 1)
      assert result == []
    end

    test "skips sessions with :not_found" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:dude1] end)
      Mimic.stub(El.Session, :log, fn :dude1, 1 -> :not_found end)

      result = El.log_pattern("dude*", 1)
      assert result == []
    end
  end

  describe "ls/0" do
    test "returns sorted list from Registry.select" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:zeta, :alpha, :beta] end)

      result = El.ls()
      assert result == [:alpha, :beta, :zeta]
    end

    test "returns empty list when no sessions" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [] end)

      assert El.ls() == []
    end
  end


end
