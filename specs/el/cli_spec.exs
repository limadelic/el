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

    test "returns start for single session name" do
      assert El.CLI.Router.parse_route(["my_session"]) == :start
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

    test "returns exit for dud* exit" do
      assert El.CLI.Router.parse_route(["dud*", "exit"]) == :exit
    end

    test "returns clear for name clear" do
      assert El.CLI.Router.parse_route(["session", "clear"]) == :clear
    end

    test "returns tell_ask for name tell ask @target message" do
      assert El.CLI.Router.parse_route(["session", "tell", "ask", "@other", "hello"]) == :tell_ask
    end

    test "returns ask_tell for name ask tell @target message" do
      assert El.CLI.Router.parse_route(["session", "ask", "tell", "@other", "hello"]) == :ask_tell
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

  describe "execute/2" do
    setup do
      Application.put_env(:el, :file_system, El.MockFileSystem)

      on_exit(fn ->
        Application.delete_env(:el, :file_system)
        System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      end)

      :ok
    end

    test "execute :log_n with number calls El.log with count" do
      expect(El.MockEl, :log, fn :session, 5 -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "5"]) end)
    end

    test "execute :log_n with number prints result" do
      expect(El.MockEl, :log, fn :session, 5 -> [{"ask", "hello", "world", %{}}] end)

      output =
        capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "5"]) end)

      assert output =~ "> hello"
    end

    test "execute :log_n with 'all' calls El.log with :all" do
      expect(El.MockEl, :log, fn :session, :all -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "all"]) end)
    end

    test "execute :log_n with 'all' prints result" do
      expect(El.MockEl, :log, fn :session, :all ->
        [{"tell", "goodbye", "see ya", %{}}]
      end)

      output =
        capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "all"]) end)

      assert output =~ "> goodbye"
    end

    test "execute :log calls El.log with count 1" do
      expect(El.MockEl, :log, fn :session, 1 -> [] end)

      capture_io(fn -> El.CLI.execute(:log, ["session", "log"]) end)
    end

    test "execute :log prints result" do
      expect(El.MockEl, :log, fn :session, 1 -> [{"ask", "hi", "reply", %{}}] end)

      output = capture_io(fn -> El.CLI.execute(:log, ["session", "log"]) end)

      assert output =~ "> hi"
    end

    test "execute :clear calls El.clear with name" do
      expect(El.MockEl, :clear, fn :session -> "cleared" end)

      capture_io(fn -> El.CLI.execute(:clear, ["session", "clear"]) end)
    end

    test "execute :clear handles not_found" do
      stub(El.MockEl, :clear, fn _ -> :not_found end)

      output =
        capture_io(fn -> El.CLI.execute(:clear, ["session", "clear"]) end)

      assert String.contains?(output, "No sessions running")
    end

    test "execute :exit_all calls El.exit(:all)" do
      expect(El.MockEl, :exit, fn :all -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:exit_all, ["exit"]) end)

      assert output =~ "exited all"
    end

    test "execute :exit with glob pattern calls El.exit_pattern" do
      expect(El.MockEl, :exit_pattern, fn "dud*" -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:exit, ["dud*", "exit"]) end)

      assert output =~ "exited sessions matching dud*"
    end

    test "execute :exit with session name calls El.exit" do
      expect(El.MockEl, :exit, fn :session -> :ok end)

      capture_io(fn -> El.CLI.execute(:exit, ["session", "exit"]) end)
    end

    test "execute :clear with glob pattern calls El.clear_pattern" do
      expect(El.MockEl, :clear_pattern, fn "dud*" -> :ok end)

      output =
        capture_io(fn -> El.CLI.execute(:clear, ["dud*", "clear"]) end)

      assert output =~ "cleared sessions matching dud*"
    end

    test "execute :clear with session name calls El.clear" do
      expect(El.MockEl, :clear, fn :session -> "cleared" end)

      capture_io(fn -> El.CLI.execute(:clear, ["session", "clear"]) end)
    end

    test "execute :log with glob pattern calls El.log_pattern" do
      expect(El.MockEl, :log_pattern, fn "dud*", 1 -> [] end)

      capture_io(fn -> El.CLI.execute(:log, ["dud*", "log"]) end)
    end

    test "execute :log with session name calls El.log" do
      expect(El.MockEl, :log, fn :session, 1 -> [] end)

      capture_io(fn -> El.CLI.execute(:log, ["session", "log"]) end)
    end

    test "execute :log_n with glob pattern calls El.log_pattern" do
      expect(El.MockEl, :log_pattern, fn "dud*", 5 -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["dud*", "log", "5"]) end)
    end

    test "execute :log_n with session name calls El.log" do
      expect(El.MockEl, :log, fn :session, 5 -> [] end)

      capture_io(fn -> El.CLI.execute(:log_n, ["session", "log", "5"]) end)
    end

    test "execute :msg auto-starts session with agent detection" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "session.md")
      end)

      expect(El.MockEl, :start, fn :session, [agent: "session"] -> :ok end)
      expect(El.MockEl, :ask, fn :session, "hello world" -> "reply" end)
      expect(El.MockEl, :agent, fn :session -> "session" end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello", "world"]) end)

      assert output =~ "reply"
    end

    test "execute :msg without agent uses session name" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      expect(El.MockEl, :ask, fn :session, "hello" -> "reply" end)
      expect(El.MockEl, :agent, fn :session -> nil end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello"]) end)

      assert output =~ "reply"
    end

    test "execute :start uses merge_session_opts to combine agent and model" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "my_session.md")
      end)

      expect(El.MockEl, :start, fn :my_session, [agent: "my_session"] -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"])
      end)
    end

    test "execute :start with -m model calls merge_session_opts with explicit model" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "my_session.md")
      end)

      expect(El.MockEl, :start, fn :my_session, [model: "haiku", agent: "my_session"] -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-m", "haiku"])
      end)
    end

    test "execute :start with -a agent skips detection and uses explicit agent" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :my_session, [agent: "explicit"] -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-a", "explicit"])
      end)
    end

    test "execute :start when no agent detected does not merge agent into opts" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :my_session, [] -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"])
      end)
    end

    test "execute :start with -m model when no agent detected does not merge agent" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :my_session, [model: "haiku"] -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-m", "haiku"])
      end)
    end

    test "execute :start uses env model when no model or agent" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :my_session, [model: "sonnet"] -> :ok end)

      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"])
      end)
    end

    test "execute :start ignores env model when model provided" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :my_session, [model: "opus"] -> :ok end)

      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session", "-m", "opus"])
      end)
    end

    test "execute :start ignores env model when agent detected" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "my_session.md")
      end)

      expect(El.MockEl, :start, fn :my_session, [agent: "my_session"] -> :ok end)

      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"])
      end)
    end

    test "execute :start ignores nil env model" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :my_session, [] -> :ok end)

      capture_io(fn ->
        El.CLI.execute(:start, ["my_session"])
      end)
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
      output = capture_io(fn -> El.CLI.dispatch(["-v"]) end)
      assert String.starts_with?(String.trim(output), "v0.1.")
    end

    test "usage message contains el ls" do
      output = capture_io(fn -> El.CLI.dispatch([]) end)
      assert String.contains?(output, "el ls")
    end

    test "usage message contains el -v" do
      output = capture_io(fn -> El.CLI.dispatch([]) end)
      assert String.contains?(output, "el -v")
    end

    test "usage message contains el exit" do
      output = capture_io(fn -> El.CLI.dispatch([]) end)
      assert String.contains?(output, "el exit")
    end

    test "usage message contains el <name|glob> exit" do
      output = capture_io(fn -> El.CLI.dispatch([]) end)
      assert String.contains?(output, "el <name|glob> exit")
    end

    test "version does not contain usage info" do
      output = capture_io(fn -> El.CLI.dispatch(["-v"]) end)
      refute String.contains?(output, "el ls")
    end

    test "version matches version format" do
      output = capture_io(fn -> El.CLI.dispatch(["-v"]) end)
      assert output =~ ~r/\d+\.\d+/
    end
  end

  describe "El.CLI.Start.merge_session_opts/3" do
    setup do
      Application.put_env(:el, :file_system, El.MockFileSystem)
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      on_exit(fn ->
        Application.delete_env(:el, :file_system)
        System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      end)

      :ok
    end

    defp setup_agent_detected do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "session.md")
      end)

      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")
    end

    test "with explicit_model prepends [model: explicit_model]" do
      result = El.CLI.Start.merge_session_opts("session", nil, "opus")

      assert Keyword.get(result, :model) == "opus"
    end

    test "with explicit_agent uses explicit_agent for agent:" do
      result = El.CLI.Start.merge_session_opts("session", "explicit", nil)

      assert Keyword.get(result, :agent) == "explicit"
    end

    test "with no explicit_agent detects agent if exists" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "session.md")
      end)

      result = El.CLI.Start.merge_session_opts("session", nil, nil)

      assert Keyword.get(result, :agent) == "session"
    end

    test "with no explicit_agent and no detected agent omits agent" do
      result = El.CLI.Start.merge_session_opts("session", nil, nil)

      refute Keyword.has_key?(result, :agent)
    end

    test "appends env_model when no model or agent" do
      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      result = El.CLI.Start.merge_session_opts("session", nil, nil)

      assert Keyword.get(result, :model) == "sonnet"
    end

    test "ignores env_model when explicit_model provided" do
      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      result = El.CLI.Start.merge_session_opts("session", nil, "opus")

      assert Keyword.get(result, :model) == "opus"
    end

    test "includes detected agent in opts" do
      setup_agent_detected()

      result = El.CLI.Start.merge_session_opts("session", nil, nil)

      assert Keyword.get(result, :agent) == "session"
    end

    test "omits model when agent detected" do
      setup_agent_detected()

      result = El.CLI.Start.merge_session_opts("session", nil, nil)

      refute Keyword.has_key?(result, :model)
    end

    test "combines explicit_model and explicit_agent" do
      result = El.CLI.Start.merge_session_opts("session", "kent", "haiku")

      assert Keyword.get(result, :model) == "haiku"
      assert Keyword.get(result, :agent) == "kent"
    end

    test "ignores env_model when explicit_agent provided" do
      System.put_env("CLAUDE_CODE_SUBAGENT_MODEL", "sonnet")

      result = El.CLI.Start.merge_session_opts("session", "explicit", nil)

      assert Keyword.get(result, :agent) == "explicit"
    end

    test "omits model when explicit_agent provided" do
      result = El.CLI.Start.merge_session_opts("session", "explicit", nil)

      refute Keyword.has_key?(result, :model)
    end

    test "merges model from agent metadata when agent detected and explicit_model is nil" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "kent.md")
      end)

      Application.put_env(:el, :agent_metadata, AgentMetadataStub)

      on_exit(fn -> Application.delete_env(:el, :agent_metadata) end)

      result = El.CLI.Start.merge_session_opts("kent", nil, nil)

      assert Keyword.get(result, :model) == "opus"
    end

    test "omits model from agent metadata if model_for returns nil" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "agent.md")
      end)

      Application.put_env(:el, :agent_metadata, NilAgentMetadataStub)

      on_exit(fn -> Application.delete_env(:el, :agent_metadata) end)

      result = El.CLI.Start.merge_session_opts("agent", nil, nil)

      refute Keyword.has_key?(result, :model)
    end
  end
end
