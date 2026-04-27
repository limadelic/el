defmodule El.Spec do
  use ExUnit.Case

  describe "start/2" do
    test "returns name when lookup returns empty" do
      Process.put(:mock_registry_lookup, fn El.Registry, _name -> [] end)
      Process.put(:mock_supervisor_start, fn El.SessionSupervisor, _args -> {:ok, :pid} end)
      assert El.start(:kent, registry: MockRegistry, supervisor: MockSupervisor) == :kent
    end

    test "returns name when session already exists" do
      Process.put(:mock_registry_lookup, fn El.Registry, :lisa -> [{:pid, :meta}] end)
      assert El.start(:lisa, registry: MockRegistry) == :lisa
    end

    test "passes options to supervisor" do
      Process.put(:mock_registry_lookup, fn El.Registry, _name -> [] end)

      Process.put(:mock_supervisor_start, fn El.SessionSupervisor,
                                             {El.Session, {_name, passed_opts}} ->
        assert passed_opts == [claude_module: MockModule]
        {:ok, :pid}
      end)

      El.start(:eric,
        claude_module: MockModule,
        registry: MockRegistry,
        supervisor: MockSupervisor
      )
    end
  end

  describe "tell/2" do
    test "delegates to El.Session.tell" do
      assert El.tell(:kent, "message", session_module: MockElSession) == :ok
      assert_received {:tell, :kent, "message"}
    end
  end

  describe "tell_ask/3" do
    test "delegates to El.Session.tell_ask" do
      assert El.tell_ask(:kent, :lisa, "message", session_module: MockElSession) == :ok
      assert_received {:tell_ask, :kent, :lisa, "message"}
    end
  end

  describe "clear/1" do
    test "delegates to El.Session.clear" do
      assert El.clear(:kent, session_module: MockElSession) == :ok
      assert_received {:clear, :kent}
    end
  end

  describe "exit/1" do
    test "returns ok when session found and terminated" do
      Process.put(:mock_registry_lookup, fn El.Registry, :kent -> [{:pid, :meta}] end)
      Process.put(:mock_supervisor_terminate, fn El.SessionSupervisor, :pid -> :ok end)
      Process.put(:mock_monitor_wait, fn _ref, _name -> :ok end)

      result =
        El.exit(:kent, registry: MockRegistry, supervisor: MockSupervisor, monitor: MockMonitor)

      assert result == :ok
    end

    test "deletes session messages on successful termination" do
      Process.put(:mock_registry_lookup, fn El.Registry, :kent -> [{:pid, :meta}] end)
      Process.put(:mock_supervisor_terminate, fn El.SessionSupervisor, :pid -> :ok end)
      Process.put(:mock_monitor_wait, fn _ref, _name -> :ok end)

      El.exit(:kent,
        registry: MockRegistry,
        supervisor: MockSupervisor,
        monitor: MockMonitor,
        app: MockElApp
      )
    end

    test "returns not_found when session not running" do
      Process.put(:mock_registry_lookup, fn El.Registry, :unknown -> [] end)
      assert El.exit(:unknown, registry: MockRegistry, app: MockElApp) == :not_found
      assert_received {:delete_session_messages, :unknown}
    end

    test "rescues errors and returns ok" do
      Process.put(:mock_registry_lookup, fn El.Registry, _name -> [{:pid, :meta}] end)
      Process.put(:mock_supervisor_terminate, fn El.SessionSupervisor, _pid -> raise "error" end)
      Process.put(:mock_monitor_wait, fn _ref, _name -> :ok end)

      result =
        El.exit(:kent, registry: MockRegistry, supervisor: MockSupervisor, monitor: MockMonitor)

      assert result == :ok
    end
  end

  describe "exit/1 with :all" do
    test "terminates all sessions" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:kent, :lisa]
      end)

      Process.put(:mock_registry_lookup, fn El.Registry, name ->
        case name do
          :kent -> [{:pid1, :meta}]
          :lisa -> [{:pid2, :meta}]
        end
      end)

      Process.put(:mock_supervisor_terminate, fn El.SessionSupervisor, _pid -> :ok end)
      Process.put(:mock_monitor_wait, fn _ref, _name -> :ok end)
      El.exit(:all, registry: MockRegistry, supervisor: MockSupervisor, monitor: MockMonitor)
    end
  end

  describe "exit_pattern/1" do
    test "exits sessions matching glob pattern" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:dude1, :dude2, :lisa]
      end)

      Process.put(:mock_registry_lookup, fn El.Registry, name ->
        case name do
          :dude1 -> [{:pid1, :meta}]
          :dude2 -> [{:pid2, :meta}]
        end
      end)

      Process.put(:mock_supervisor_terminate, fn El.SessionSupervisor, _pid -> :ok end)
      Process.put(:mock_monitor_wait, fn _ref, _name -> :ok end)

      El.exit_pattern("dude*",
        registry: MockRegistry,
        supervisor: MockSupervisor,
        monitor: MockMonitor
      )
    end

    test "exits no sessions when pattern matches nothing" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:alice, :bob]
      end)

      result = El.exit_pattern("charlie*", registry: MockRegistry)
      assert result == :ok
    end
  end

  describe "clear_pattern/1" do
    test "clears sessions matching glob pattern" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:dude1, :dude2, :lisa]
      end)

      El.clear_pattern("dude*", registry: MockRegistry, session_module: MockElSession)
      assert_received {:clear, :dude1}
      assert_received {:clear, :dude2}
    end

    test "clears no sessions when pattern matches nothing" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:alice, :bob]
      end)

      result = El.clear_pattern("charlie*", registry: MockRegistry, session_module: MockElSession)
      assert result == :ok
    end
  end

  describe "log_pattern/2" do
    test "returns logs from sessions matching glob pattern" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:dude1, :dude2, :lisa]
      end)

      Process.put({:mock_log, :dude1}, [{"ask", "hi", "reply", %{}}])
      Process.put({:mock_log, :dude2}, [{"tell", "hello", "world", %{}}])
      result = El.log_pattern("dude*", 1, registry: MockRegistry, session_module: MockElSession)
      assert length(result) == 2
    end

    test "returns empty list when pattern matches nothing" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:alice, :bob]
      end)

      result =
        El.log_pattern("charlie*", 1, registry: MockRegistry, session_module: MockElSession)

      assert result == []
    end

    test "skips sessions with :not_found" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:dude1]
      end)

      result = El.log_pattern("dude*", 1, registry: MockRegistry, session_module: MockElSession)
      assert result == []
    end
  end

  describe "ls/0" do
    test "returns sorted list from Registry.select" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        [:zeta, :alpha, :beta]
      end)

      result = El.ls(registry: MockRegistry)
      assert result == [:alpha, :beta, :zeta]
    end

    test "returns empty list when no sessions" do
      Process.put(:mock_registry_select, fn El.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}] ->
        []
      end)

      assert El.ls(registry: MockRegistry) == []
    end
  end
end

defmodule MockRegistry do
  def lookup(El.Registry, name) do
    case Process.get(:mock_registry_lookup) do
      nil -> []
      behavior -> behavior.(El.Registry, name)
    end
  rescue
    _ -> []
  end

  def select(El.Registry, pattern) do
    case Process.get(:mock_registry_select) do
      nil -> []
      behavior -> behavior.(El.Registry, pattern)
    end
  rescue
    _ -> []
  end
end

defmodule MockSupervisor do
  def start_child(supervisor_name, args) do
    case Process.get(:mock_supervisor_start) do
      nil -> {:ok, :pid}
      behavior -> behavior.(supervisor_name, args)
    end
  rescue
    _ -> {:ok, :pid}
  end

  def terminate_child(supervisor_name, pid) do
    case Process.get(:mock_supervisor_terminate) do
      nil -> :ok
      behavior -> behavior.(supervisor_name, pid)
    end
  rescue
    _ -> :ok
  end
end

defmodule MockMonitor do
  def wait_for_down(ref, name) do
    case Process.get(:mock_monitor_wait) do
      nil -> :ok
      behavior -> behavior.(ref, name)
    end
  rescue
    _ -> :ok
  end
end

defmodule MockElSession do
  def tell(name, message) do
    send(self(), {:tell, name, message})
    :ok
  end

  def clear(name) do
    send(self(), {:clear, name})
    :ok
  end

  def tell_ask(name, target, message) do
    send(self(), {:tell_ask, name, target, message})
    :ok
  end

  def ask_tell(name, target, message) do
    send(self(), {:ask_tell, name, target, message})
    :ok
  end

  def log(name, count) do
    send(self(), {:log, name, count})

    case Process.get({:mock_log, name}) do
      nil -> :not_found
      val -> val
    end
  end
end

defmodule MockElApp do
  def delete_session_messages(name) do
    send(self(), {:delete_session_messages, name})
    :ok
  end
end
