defmodule El.CLI.Spec do
  use ExUnit.Case
  import Mox
  import ExUnit.CaptureIO

  setup :verify_on_exit!

  describe "parse_route/1" do
    test "returns usage when no args" do
      assert El.CLI.Router.parse_route([]) == :usage
    end

    test "returns ls for ls command" do
      assert El.CLI.Router.parse_route(["ls"]) == :ls
    end

    test "returns restart_daemon for [restart]" do
      assert El.CLI.Router.parse_route(["restart"]) == :restart_daemon
    end

    test "returns info for single session name" do
      assert El.CLI.Router.parse_route(["my_session"]) == :info
    end

    test "returns start with -m flag" do
      assert El.CLI.Router.parse_route(["my_session", "-m", "haiku"]) == :start
    end

    test "returns start with -a flag" do
      assert El.CLI.Router.parse_route(["my_session", "-a", "kent"]) == :start
    end

    test "returns msg for name word message" do
      assert El.CLI.Router.parse_route(["session", "hello"]) == :msg
    end

    test "returns msg for name multiple words" do
      assert El.CLI.Router.parse_route(["session", "hello", "world", "foo"]) == :msg
    end

    test "routes arbitrary args to msg" do
      assert El.CLI.Router.parse_route(["bogus", "args"]) == :msg
    end

    test "returns :info_json for name with -json" do
      assert El.CLI.Router.parse_route(["myagent", "-json"]) == :info_json
    end

    test "returns :log_json for [name, \"log\", \"-json\"]" do
      assert El.CLI.Router.parse_route(["myagent", "log", "-json"]) == :log_json
    end

    test "returns :log_n_json for name log n with -json" do
      assert El.CLI.Router.parse_route(["myagent", "log", "5", "-json"]) == :log_n_json
    end

    test "returns log for name log" do
      assert El.CLI.Router.parse_route(["session", "log"]) == :log
    end

    test "returns log_n for name log with number" do
      assert El.CLI.Router.parse_route(["session", "log", "5"]) == :log_n
    end

    test "returns log_n for name log all" do
      assert El.CLI.Router.parse_route(["session", "log", "all"]) == :log_n
    end

    test "returns exit for name exit" do
      assert El.CLI.Router.parse_route(["session", "exit"]) == :exit
    end

    test "returns exit_all for exit" do
      assert El.CLI.Router.parse_route(["exit"]) == :exit_all
    end

    test "returns clear_all for clear" do
      assert El.CLI.Router.parse_route(["clear"]) == :clear_all
    end

    test "returns exit for dud* exit" do
      assert El.CLI.Router.parse_route(["dud*", "exit"]) == :exit
    end

    test "returns clear for name clear" do
      assert El.CLI.Router.parse_route(["session", "clear"]) == :clear
    end

    test "returns restart for name restart" do
      assert El.CLI.Router.parse_route(["my_session", "restart"]) == :restart
    end

    test "returns daemon for --daemon flag" do
      assert El.CLI.Router.parse_route(["--daemon", "my_session"]) == :daemon
    end

    test "returns daemon with -m flag" do
      assert El.CLI.Router.parse_route(["--daemon", "my_session", "-m", "opus"]) == :daemon
    end

    test "returns version for -v" do
      assert El.CLI.Router.parse_route(["-v"]) == :version
    end

    test "returns usage for args starting with --" do
      assert El.CLI.Router.parse_route(["--nonsense"]) == :usage
    end

    test "returns usage for args starting with -" do
      assert El.CLI.Router.parse_route(["-x"]) == :usage
    end
  end

  describe "execute/3" do
    setup do
      System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      Application.put_env(:el, :file_system, El.MockFileSystem)
      stub(El.MockSessionApi, :info, fn _name -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      on_exit(fn ->
        Application.delete_env(:el, :file_system)
        System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      end)

      :ok
    end

    test "execute :log_n with number calls El.log with count" do
      expect(El.MockEl, :log, fn :session, 5, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "5"], [el_module: El.MockEl]) end)
    end

    test "execute :log_n with number prints result" do
      expect(El.MockEl, :log, fn :session, 5, _opts -> [{"ask", "hello", "world", %{}}] end)

      output =
        capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "5"], [el_module: El.MockEl]) end)

      assert output =~ "> hello"
    end

    test "execute :log_n with 'all' calls El.log with :all" do
      expect(El.MockEl, :log, fn :session, :all, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "all"], [el_module: El.MockEl]) end)
    end

    test "execute :log_n with 'all' prints result" do
      expect(El.MockEl, :log, fn :session, :all, _opts ->
        [{"tell", "goodbye", "see ya", %{}}]
      end)

      output =
        capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "all"], [el_module: El.MockEl]) end)

      assert output =~ "> goodbye"
    end

    test "execute :log calls El.log with count 1" do
      expect(El.MockEl, :log, fn :session, 1, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log, ["session", "log"], [el_module: El.MockEl]) end)
    end

    test "execute :log prints result" do
      expect(El.MockEl, :log, fn :session, 1, _opts -> [{"ask", "hi", "reply", %{}}] end)

      output = capture_io(fn -> El.CLI.execute(:log, ["session", "log"], [el_module: El.MockEl]) end)

      assert output =~ "> hi"
    end

    test "execute :clear calls El.clear with name" do
      expect(El.MockEl, :clear, fn :session, _opts -> "cleared" end)

      capture_io(fn -> El.CLI.execute(:clear, ["session", "clear"], [el_module: El.MockEl]) end)
    end

    test "execute :clear handles not_found" do
      stub(El.MockEl, :clear, fn _, _opts -> :not_found end)

      output =
        capture_io(fn -> El.CLI.execute(:clear, ["session", "clear"], [el_module: El.MockEl]) end)

      assert String.contains?(output, "No sessions running")
    end

    test "execute :exit_all calls El.exit(:all)" do
      expect(El.MockEl, :exit, fn :all, _opts -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:exit_all, ["exit"], [el_module: El.MockEl]) end)

      assert output =~ "exited all"
    end

    test "execute :clear_all calls El.clear_pattern with '*'" do
      expect(El.MockEl, :clear_pattern, fn "*", _opts -> :ok end)

      capture_io(fn -> El.CLI.execute(:clear_all, ["clear"], [el_module: El.MockEl]) end)
    end

    test "execute :clear_all prints confirmation" do
      stub(El.MockEl, :clear_pattern, fn "*", _opts -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:clear_all, ["clear"], [el_module: El.MockEl]) end)

      assert output =~ "cleared all"
    end

    test "execute :exit with glob pattern calls El.exit_pattern" do
      expect(El.MockEl, :exit_pattern, fn "dud*", _opts -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:exit, ["dud*", "exit"], [el_module: El.MockEl]) end)

      assert output =~ "exited sessions matching dud*"
    end

    test "execute :exit with session name calls El.exit" do
      expect(El.MockEl, :exit, fn :session, _opts -> :ok end)

      capture_io(fn -> El.CLI.execute(:exit, ["session", "exit"], [el_module: El.MockEl]) end)
    end

    test "execute :clear with glob pattern calls El.clear_pattern" do
      expect(El.MockEl, :clear_pattern, fn "dud*", _opts -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:clear, ["dud*", "clear"], [el_module: El.MockEl]) end)

      assert output =~ "cleared sessions matching dud*"
    end

    test "execute :clear with session name calls El.clear" do
      expect(El.MockEl, :clear, fn :session, _opts -> "cleared" end)

      capture_io(fn -> El.CLI.execute(:clear, ["session", "clear"], [el_module: El.MockEl]) end)
    end

    test "execute :log with glob pattern calls El.log_pattern" do
      expect(El.MockEl, :log_pattern, fn "dud*", 1, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log, ["dud*", "log"], [el_module: El.MockEl]) end)
    end

    test "execute :log with session name calls El.log" do
      expect(El.MockEl, :log, fn :session, 1, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log, ["session", "log"], [el_module: El.MockEl]) end)
    end

    test "execute :log_n with glob pattern calls El.log_pattern" do
      expect(El.MockEl, :log_pattern, fn "dud*", 5, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["dud*", "log", "5"], [el_module: El.MockEl]) end)
    end

    test "execute :log_n with session name calls El.log" do
      expect(El.MockEl, :log, fn :session, 5, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "5"], [el_module: El.MockEl]) end)
    end

    test "execute :log_n with glob and \"all\" calls El.log_pattern with :all" do
      expect(El.MockEl, :log_pattern, fn "dud*", :all, _opts -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["dud*", "log", "all"], el_module: El.MockEl) end)
    end

    test "execute :msg auto-starts session with agent detection" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :created end)
      expect(El.MockEl, :ask, fn :session, "hello world", _opts -> "reply" end)
      expect(El.MockEl, :agent, fn :session, _opts -> "session" end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello", "world"], [agent_detector: IdentityAgentDetectorStub, el_module: El.MockEl]) end)

      assert output =~ "reply"
    end

    test "execute :msg without agent uses session name" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :created end)
      expect(El.MockEl, :ask, fn :session, "hello", _opts -> "reply" end)
      expect(El.MockEl, :agent, fn :session, _opts -> nil end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello"], [agent_detector: NilAgentDetectorStub, el_module: El.MockEl]) end)

      assert output =~ "reply"
    end

    test "execute :msg prints boxed card after response" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :created end)
      expect(El.MockEl, :ask, fn :session, "hello", _opts -> "reply" end)
      expect(El.MockEl, :agent, fn :session, _opts -> nil end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello"], [agent_detector: NilAgentDetectorStub, el_module: El.MockEl]) end)

      assert output =~ "name:  session"
    end

    test "execute :msg skips card when session already running" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :already_running end)
      expect(El.MockEl, :ask, fn :session, "hello", _opts -> "reply" end)
      expect(El.MockEl, :agent, fn :session, _opts -> nil end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello"], [agent_detector: NilAgentDetectorStub, el_module: El.MockEl]) end)

      assert output =~ "reply"
      refute output =~ "name:  session"
    end

    test "execute :msg shows card when session newly created" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :created end)
      expect(El.MockEl, :ask, fn :session, "hello", _opts -> "reply" end)
      expect(El.MockEl, :agent, fn :session, _opts -> nil end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello"], [agent_detector: NilAgentDetectorStub, el_module: El.MockEl]) end)

      assert output =~ "reply"
      assert output =~ "name:  session"
    end

    test "execute :msg uses agent metadata model when agent detected" do
      test_pid = self()
      expect(El.MockEl, :start, fn :kent, opts ->
        send(test_pid, {:start_opts, opts})
        :created
      end)
      expect(El.MockEl, :ask, fn :kent, "hello", _opts -> "reply" end)
      expect(El.MockEl, :agent, fn :kent, _opts -> nil end)

      capture_io(fn ->
        El.CLI.execute(:msg, ["kent", "hello"],
          [agent_detector: AgentDetectorStub, agent_metadata: AgentMetadataStub, el_module: El.MockEl])
      end)

      assert_received {:start_opts, opts}
      assert opts[:model] == "opus"
    end

    test "execute :start uses merge_session_opts to combine agent and model" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :ask, fn :my_session, "who are you?" -> "response" end)
      expect(El.MockGroupLeader, :open_null_device, fn -> self() end)
      expect(El.MockGroupLeader, :get, fn -> self() end)
      expect(El.MockGroupLeader, :set, fn _, _ -> true end)
      expect(El.MockGroupLeader, :set, fn _, _ -> true end)
      expect(El.MockGroupLeader, :close, fn _ -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"], [agent_detector: IdentityAgentDetectorStub, session_api: El.MockSessionApi, group_leader: El.MockGroupLeader, el_module: El.MockEl])
      end)
    end

    test "execute :start with -m model calls merge_session_opts with explicit model" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :info, 2, fn :my_session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, fn :my_session, "who are you?" -> "response" end)
      expect(El.MockGroupLeader, :open_null_device, fn -> :null_device end)
      expect(El.MockGroupLeader, :get, fn -> :original_leader end)
      expect(El.MockGroupLeader, :set, 2, fn _, _ -> true end)
      expect(El.MockGroupLeader, :close, fn _ -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-m", "haiku"], [agent_detector: IdentityAgentDetectorStub, session_api: El.MockSessionApi, group_leader: El.MockGroupLeader, el_module: El.MockEl])
      end)
    end

    test "execute :start with -a agent skips detection and uses explicit agent" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :info, 2, fn :my_session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, fn :my_session, "who are you?" -> "response" end)
      expect(El.MockGroupLeader, :open_null_device, fn -> :null_device end)
      expect(El.MockGroupLeader, :get, fn -> :original_leader end)
      expect(El.MockGroupLeader, :set, 2, fn _, _ -> true end)
      expect(El.MockGroupLeader, :close, fn _ -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-a", "explicit"], [agent_detector: NilAgentDetectorStub, session_api: El.MockSessionApi, group_leader: El.MockGroupLeader, el_module: El.MockEl])
      end)
    end

    test "execute :start when no agent detected does not merge agent into opts" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :info, 2, fn :my_session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"], [agent_detector: NilAgentDetectorStub, session_api: El.MockSessionApi, el_module: El.MockEl])
      end)
    end

    test "execute :start with -m model when no agent detected does not merge agent" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :info, 2, fn :my_session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-m", "haiku"], [agent_detector: NilAgentDetectorStub, session_api: El.MockSessionApi, el_module: El.MockEl])
      end)
    end

    test "execute :start uses env model when no model or agent" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :info, 2, fn :my_session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"], [agent_detector: NilAgentDetectorStub, session_api: El.MockSessionApi, el_module: El.MockEl])
      end)
    end

    test "execute :start ignores env model when model provided" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :info, 2, fn :my_session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-m", "opus"], [agent_detector: NilAgentDetectorStub, session_api: El.MockSessionApi, el_module: El.MockEl])
      end)
    end

    test "execute :start ignores env model when agent detected" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :ask, fn :my_session, "who are you?" -> "response" end)
      expect(El.MockGroupLeader, :open_null_device, fn -> self() end)
      expect(El.MockGroupLeader, :get, fn -> self() end)
      expect(El.MockGroupLeader, :set, fn _, _ -> true end)
      expect(El.MockGroupLeader, :set, fn _, _ -> true end)
      expect(El.MockGroupLeader, :close, fn _ -> :ok end)

      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"], [agent_detector: IdentityAgentDetectorStub, session_api: El.MockSessionApi, group_leader: El.MockGroupLeader, el_module: El.MockEl])
      end)
    end

    test "execute :start ignores nil env model" do
      expect(El.MockEl, :start, fn :my_session, opts when is_list(opts) -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"], [agent_detector: NilAgentDetectorStub, el_module: El.MockEl])
      end)
    end

    test "execute :info outputs session name" do
      stub(El.MockSessionApi, :alive?, fn :session -> true end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 2, last_prompt: "who?", last_response: "me", model: "haiku", cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.execute(:info, ["session"], [session_api: El.MockSessionApi])
        end)

      assert output =~ "session"
    end

    test "execute :info falls back to usage when session absent" do
      stub(El.MockSessionApi, :alive?, fn :session -> false end)

      output =
        capture_io(fn ->
          El.CLI.execute(:info, ["session"], [session_api: El.MockSessionApi])
        end)

      assert output =~ "el ls"
    end

    test "execute :restart calls El.restart on the named session" do
      expect(El.MockEl, :restart, fn :session, _opts -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who?", last_response: "me", model: "haiku", cwd: nil, id: nil} end)

      capture_io(fn ->
        El.CLI.execute(:restart, ["session"], [el_module: El.MockEl, session_api: El.MockSessionApi])
      end)
    end

    test "execute :restart prints the session card" do
      stub(El.MockEl, :restart, fn :session, _opts -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who?", last_response: "me", model: "haiku", cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.execute(:restart, ["session"], [el_module: El.MockEl, session_api: El.MockSessionApi])
        end)

      assert output =~ "session"
    end

    test "execute :restart with glob pattern prints confirmation" do
      expect(El.MockEl, :restart_pattern, fn "foo*", _opts -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:restart, ["foo*", "restart"], [el_module: El.MockEl]) end)

      assert output =~ "restarted sessions matching foo*"
    end

    test "execute :restart_daemon calls Daemon.restart_daemon" do
      expect(El.MockDaemon, :restart_daemon, fn _opts -> :ok end)

      capture_io(fn -> El.CLI.execute(:restart_daemon, ["restart"], [daemon_module: El.MockDaemon]) end)
    end

    test "execute :restart_daemon prints status" do
      stub(El.MockDaemon, :restart_daemon, fn _opts -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:restart_daemon, ["restart"], [daemon_module: El.MockDaemon]) end)

      assert output =~ "daemon restarted"
    end

    test "execute :info_json outputs dead JSON when session not alive" do
      stub(El.MockSessionApi, :alive?, fn :ghost -> false end)
      output = capture_io(fn ->
        El.CLI.execute(:info_json, ["ghost"], [session_api: El.MockSessionApi])
      end)
      assert Jason.decode!(String.trim(output)) == %{"name" => "ghost", "alive" => false}
    end
  end

  describe "daemon spawning" do
    test "daemon_script returns absolute path" do
      path = El.CLI.Daemon.daemon_script()
      assert String.starts_with?(path, "/")
    end

    test "dev? returns true when DEV is set" do
      System.put_env("DEV", "1")
      assert El.CLI.Daemon.dev?() == true
      System.delete_env("DEV")
    end

    test "daemon_node returns el_dev@127.0.0.1 when DEV is set" do
      System.put_env("DEV", "1")
      assert El.CLI.Daemon.daemon_node() == :"el_dev@127.0.0.1"
      System.delete_env("DEV")
    end
  end

  describe "dispatch/1" do
    test "version starts with v0.1." do
      output = capture_io(fn -> El.CLI.dispatch(["-v"], []) end)
      assert String.starts_with?(String.trim(output), "v0.1.")
    end

    test "usage message contains el ls" do
      output = capture_io(fn -> El.CLI.dispatch([], []) end)
      assert String.contains?(output, "el ls")
    end

    test "usage message contains el -v" do
      output = capture_io(fn -> El.CLI.dispatch([], []) end)
      assert String.contains?(output, "el -v")
    end

    test "usage message contains el exit" do
      output = capture_io(fn -> El.CLI.dispatch([], []) end)
      assert String.contains?(output, "el exit")
    end

    test "usage message contains el <name|glob> exit" do
      output = capture_io(fn -> El.CLI.dispatch([], []) end)
      assert String.contains?(output, "el <name|glob> exit")
    end

    test "version does not contain usage info" do
      output = capture_io(fn -> El.CLI.dispatch(["-v"], []) end)
      refute String.contains?(output, "el ls")
    end

    test "version matches version format" do
      output = capture_io(fn -> El.CLI.dispatch(["-v"], []) end)
      assert output =~ ~r/\d+\.\d+/
    end
  end

  describe "El.CLI.Start.Options.merge_session_opts/4" do
    setup do
      System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      :ok
    end

    defp setup_agent_detected do
      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")
    end

    test "with explicit_model prepends [model: explicit_model]" do
      result = El.CLI.Start.Options.merge_session_opts("session", nil, "opus", [agent_detector: NilAgentDetectorStub])

      assert Keyword.get(result, :model) == "opus"
    end

    test "with explicit_agent uses explicit_agent for agent:" do
      result = El.CLI.Start.Options.merge_session_opts("session", "explicit", nil, [agent_detector: NilAgentDetectorStub])

      assert Keyword.get(result, :agent) == "explicit"
    end

    test "with no explicit_agent detects agent if exists" do
      result = El.CLI.Start.Options.merge_session_opts("session", nil, nil, [agent_detector: IdentityAgentDetectorStub])

      assert Keyword.get(result, :agent) == "session"
    end

    test "with no explicit_agent and no detected agent omits agent" do
      result = El.CLI.Start.Options.merge_session_opts("session", nil, nil, [agent_detector: NilAgentDetectorStub])

      refute Keyword.has_key?(result, :agent)
    end

    test "appends env_model when no model or agent" do
      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      result = El.CLI.Start.Options.merge_session_opts("session", nil, nil, [agent_detector: NilAgentDetectorStub])

      assert Keyword.get(result, :model) == "sonnet"
    end

    test "ignores env_model when explicit_model provided" do
      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      result = El.CLI.Start.Options.merge_session_opts("session", nil, "opus", [agent_detector: NilAgentDetectorStub])

      assert Keyword.get(result, :model) == "opus"
    end

    test "includes detected agent in opts" do
      setup_agent_detected()

      result = El.CLI.Start.Options.merge_session_opts("session", nil, nil, [agent_detector: IdentityAgentDetectorStub])

      assert Keyword.get(result, :agent) == "session"
    end

    test "omits model when agent detected" do
      setup_agent_detected()

      result = El.CLI.Start.Options.merge_session_opts("session", nil, nil, [agent_detector: IdentityAgentDetectorStub])

      refute Keyword.has_key?(result, :model)
    end

    test "combines explicit_model and explicit_agent" do
      result = El.CLI.Start.Options.merge_session_opts("session", "kent", "haiku", [agent_detector: NilAgentDetectorStub])

      assert Keyword.get(result, :model) == "haiku"
      assert Keyword.get(result, :agent) == "kent"
    end

    test "ignores env_model when explicit_agent provided" do
      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      result = El.CLI.Start.Options.merge_session_opts("session", "explicit", nil, [agent_detector: NilAgentDetectorStub])

      assert Keyword.get(result, :agent) == "explicit"
    end

    test "omits model when explicit_agent provided" do
      result = El.CLI.Start.Options.merge_session_opts("session", "explicit", nil, [agent_detector: NilAgentDetectorStub])

      refute Keyword.has_key?(result, :model)
    end

    test "merges model from agent metadata when agent detected and explicit_model is nil" do
      System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")

      result = El.CLI.Start.Options.merge_session_opts("kent", nil, nil, [agent_detector: AgentDetectorStub, agent_metadata: AgentMetadataStub])

      assert Keyword.get(result, :model) == "opus"
    end

    test "omits model from agent metadata if model_for returns nil" do
      System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")

      result = El.CLI.Start.Options.merge_session_opts("agent", nil, nil, [agent_detector: NilAgentDetectorStub, agent_metadata: NilAgentMetadataStub])

      refute Keyword.has_key?(result, :model)
    end
  end

  describe "El.CLI.Start.handle_find_daemon_for_start/4" do
    setup do
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      :ok
    end

    test "renders boxed output with name in first row" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "name:  session"
    end

    test "renders boxed output with agent when present in opts" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :ask, fn :session, "who are you?" -> "response" end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "agent: kent"
    end

    test "renders boxed output with model when present in opts" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [model: "opus"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "model: opus"
    end

    test "renders boxed output with msgs count" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 5, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "msgs:  5"
    end

    test "renders boxed output with prompt when present" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "> who are you?"
    end

    test "renders boxed output with response when present" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: "I am an agent", model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "I am an agent"
    end

    test "omits agent row when agent not in opts" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "agent:"
    end

    test "omits model row when model not in opts" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "model:"
    end

    test "shows model from info when opts model is nil but info.model exists" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: "haiku", cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "model: haiku"
    end

    test "omits prompt separator and prompt when last_prompt is nil" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ ">"
    end

    test "wraps long response using format_response" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      long_response = "I'm Dude, man. The rug that ties this whole stack together."
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: long_response, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "stack together."
    end

    test "caps response at 2 lines" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      long_response = "This is a very long response that will definitely wrap across multiple lines when formatted with word awareness at 46 characters per line"
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: long_response, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      response_lines = Enum.filter(lines, fn line -> String.contains?(line, ["definitely", "word", "awareness"]) end)
      assert length(response_lines) <= 2
    end

    test "sends ping when agent in opts" do
      stub(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, fn :session, "who are you?" -> "response" end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_for_start("session", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
      end)
    end

    test "does not send ping when no agent in opts" do
      stub(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, 0, fn _, _ -> "response" end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
      end)
    end

    test "does not send ping when session has existing messages" do
      stub(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 5, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, 0, fn _, _ -> "response" end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_for_start("session", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
      end)
    end

    test "omits msgs row when messages count is zero" do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "msgs:"
    end

    defp setup_cwd_id_session do
      expect(El.MockEl, :start, fn :session, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: "/abc/def", id: "abc123def456"} end)
    end

    test "renders name in two-column format" do
      setup_cwd_id_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "name:  session"
    end

    test "omits cwd row when no second left row (no agent or model)" do
      setup_cwd_id_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "cwd:"
    end

    test "renders id in two-column format" do
      setup_cwd_id_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "id: …23def456"
    end

    defp setup_anom_case do
      expect(El.MockEl, :start, fn :anom, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :anom -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: "/a/b/c/d/e/f/g/h", id: "xyz789abc123"} end)
    end

    test "renders name with cwd in two-column first row" do
      setup_anom_case()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "name:  anom"
    end

    test "omits cwd when anom has no model" do
      setup_anom_case()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "cwd:"
    end

    test "renders truncated id in anom case" do
      setup_anom_case()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "id: …89abc123"
    end

    test "omits agent row for anom" do
      setup_anom_case()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "agent:"
    end

    test "omits model row for anom" do
      setup_anom_case()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "model:"
    end

    test "omits msgs row for anom" do
      setup_anom_case()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      refute output =~ "msgs:"
    end

    defp setup_agent_kent_session do
      expect(El.MockEl, :start, fn :kent, opts when is_list(opts) -> :ok end)
      expect(El.MockSessionApi, :ask, fn :kent, "who are you?" -> "response" end)
      stub(El.MockSessionApi, :info, fn :kent -> %{messages: 0, last_prompt: nil, last_response: nil, model: "opus", cwd: "/verylong/path/name", id: "kent1234567890"} end)
    end

    test "renders name for agent sessions" do
      setup_agent_kent_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "name:  kent"
    end

    test "renders truncated cwd for agent sessions" do
      setup_agent_kent_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "cwd: …ath/name"
    end

    test "renders agent with id in second row for agent sessions" do
      setup_agent_kent_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "agent: kent"
    end

    test "renders truncated id for agent sessions" do
      setup_agent_kent_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "id: …34567890"
    end

    test "renders model for agent sessions" do
      setup_agent_kent_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      assert output =~ "model: opus"
    end

    test "renders name in cwd/id pairing" do
      setup_cwd_id_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      second_line = Enum.at(lines, 1)
      assert second_line =~ "name:  session"
    end

    test "renders id in cwd/id pairing" do
      setup_cwd_id_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      second_line = Enum.at(lines, 1)
      assert second_line =~ "id: …23def456"
    end

    test "renders agent in agent/cwd pairing" do
      setup_agent_kent_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      third_line = Enum.at(lines, 2)
      assert third_line =~ "agent: kent"
    end

    test "renders cwd in agent/cwd pairing" do
      setup_agent_kent_session()

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      third_line = Enum.at(lines, 2)
      assert third_line =~ "cwd: …ath/name"
    end

    test "renders model in model/cwd pairing when no agent" do
      expect(El.MockEl, :start, fn :anom, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :anom -> %{messages: 0, last_prompt: nil, last_response: nil, model: "haiku", cwd: "/abc/def", id: "xyz789abc123"} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      third_line = Enum.at(lines, 2)
      assert third_line =~ "model: haiku"
    end

    test "renders cwd in model/cwd pairing when no agent" do
      expect(El.MockEl, :start, fn :anom, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :anom -> %{messages: 0, last_prompt: nil, last_response: nil, model: "haiku", cwd: "/abc/def", id: "xyz789abc123"} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      third_line = Enum.at(lines, 2)
      assert third_line =~ "cwd: /abc/def"
    end

    test "drops cwd row when only name exists" do
      expect(El.MockEl, :start, fn :anom, opts when is_list(opts) -> :ok end)
      stub(El.MockSessionApi, :info, fn :anom -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: "/abc/def", id: "xyz789abc123"} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl, [session_api: El.MockSessionApi])
        end)

      lines = String.split(output, "\n")
      box_lines = Enum.filter(lines, fn line -> String.starts_with?(line, "│") end)
      assert length(box_lines) == 1
    end
  end

  describe "El.CLI.Start.handle_find_daemon_with_rest/5" do
    setup do
      stub(El.MockSessionApi, :info, fn :kenny -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      stub(El.MockSessionApi, :ask, fn _, _ -> "test response" end)
      stub(El.MockGroupLeader, :open_null_device, fn -> :null_device end)
      stub(El.MockGroupLeader, :get, fn -> :original_leader end)
      stub(El.MockGroupLeader, :set, fn _, _ -> true end)
      stub(El.MockGroupLeader, :close, fn _ -> :ok end)
      :ok
    end

    test "renders boxed output with agent when provided" do
      expect(El.MockEl, :start, fn :kenny, opts when is_list(opts) -> :ok end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_with_rest("kenny", [agent: "kent"], [], El.MockEl, [session_api: El.MockSessionApi, group_leader: El.MockGroupLeader])
        end)

      assert output =~ "agent: kent"
    end

    test "renders boxed output with model when agent has default model" do
      Application.put_env(:el, :agent_metadata, AgentMetadataStub)

      on_exit(fn ->
        Application.delete_env(:el, :agent_metadata)
      end)

      expect(El.MockEl, :start, fn :kenny, opts when is_list(opts) -> :ok end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_with_rest("kenny", [agent: "kent", model: "opus"], [], El.MockEl, [session_api: El.MockSessionApi, group_leader: El.MockGroupLeader])
        end)

      assert output =~ "model: opus"
    end

  end

  describe "El.CLI.Start.format_response/1" do
    test "returns empty list when nil" do
      assert El.CLI.Start.TextFormatter.format_response(nil) == []
    end

    test "returns single-element list for short text" do
      assert El.CLI.Start.TextFormatter.format_response("kent") == ["kent"]
    end

    test "wraps at 46 characters with word awareness" do
      text = "I'm Dude, man. The rug that ties this whole stack together."
      result = El.CLI.Start.TextFormatter.format_response(text)

      assert result == ["I'm Dude, man. The rug that ties this whole", "stack together."]
    end

    test "caps at 2 lines maximum" do
      long_text = "This is a very long response that will definitely wrap across multiple lines when formatted with word awareness at 46 characters per line"
      result = El.CLI.Start.TextFormatter.format_response(long_text)

      assert length(result) == 2
    end

    test "respects 46 character line width" do
      text = "I'm Dude, man. The rug that ties this whole stack together."
      result = El.CLI.Start.TextFormatter.format_response(text)
      assert Enum.all?(result, fn line -> String.length(line) <= 46 end)
    end

    test "preserves short lines under 46 chars" do
      assert El.CLI.Start.TextFormatter.format_response("short") == ["short"]
    end
  end

end
