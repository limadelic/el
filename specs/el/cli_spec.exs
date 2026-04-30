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
      stub(El.MockSessionApi, :info, fn _name -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

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

    test "execute :msg prints boxed card after response" do
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      expect(El.MockEl, :ask, fn :session, "hello" -> "reply" end)
      expect(El.MockEl, :agent, fn :session -> nil end)

      output =
        capture_io(fn -> El.CLI.execute(:msg, ["session", "hello"]) end)

      assert output =~ "name:  session"
    end

    test "execute :start uses merge_session_opts to combine agent and model" do
      stub(El.MockFileSystem, :exists?, fn path ->
        String.contains?(path, "my_session.md")
      end)

      expect(El.MockEl, :start, fn :my_session, [agent: "my_session"] -> :ok end)
      expect(El.MockSessionApi, :ask, fn :my_session, "who are you?" -> "response" end)

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
      expect(El.MockSessionApi, :ask, fn :my_session, "who are you?" -> "response" end)

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
      System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      Application.put_env(:el, :agent_detector, AgentDetectorStub)
      Application.put_env(:el, :agent_metadata, AgentMetadataStub)

      on_exit(fn ->
        Application.delete_env(:el, :agent_detector)
        Application.delete_env(:el, :agent_metadata)
      end)

      result = El.CLI.Start.merge_session_opts("kent", nil, nil)

      assert Keyword.get(result, :model) == "opus"
    end

    test "omits model from agent metadata if model_for returns nil" do
      System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      Application.put_env(:el, :agent_detector, NilAgentDetectorStub)
      Application.put_env(:el, :agent_metadata, NilAgentMetadataStub)

      on_exit(fn ->
        Application.delete_env(:el, :agent_detector)
        Application.delete_env(:el, :agent_metadata)
      end)

      result = El.CLI.Start.merge_session_opts("agent", nil, nil)

      refute Keyword.has_key?(result, :model)
    end
  end

  describe "El.CLI.Start.detect_and_merge_agent/2" do
    setup do
      Application.put_env(:el, :file_system, El.MockFileSystem)
      stub(El.MockFileSystem, :exists?, fn _path -> false end)

      on_exit(fn ->
        Application.delete_env(:el, :file_system)
        System.delete_env("CLAUDE_CODE_SUBAGENT_MODEL")
      end)

      :ok
    end

    test "detects agent through injected detector" do
      Application.put_env(:el, :agent_detector, AgentDetectorStub)

      on_exit(fn ->
        Application.delete_env(:el, :agent_detector)
      end)

      result = El.CLI.Start.detect_and_merge_agent("kent", [])

      assert Keyword.get(result, :agent) == "kent"
    end

    test "includes opts in result" do
      Application.put_env(:el, :agent_detector, NilAgentDetectorStub)

      on_exit(fn ->
        Application.delete_env(:el, :agent_detector)
      end)

      result = El.CLI.Start.detect_and_merge_agent("session", [model: "haiku"])

      assert Keyword.get(result, :model) == "haiku"
    end

    test "handles nil agent from detector" do
      Application.put_env(:el, :agent_detector, NilAgentDetectorStub)

      on_exit(fn ->
        Application.delete_env(:el, :agent_detector)
      end)

      result = El.CLI.Start.detect_and_merge_agent("session", [])

      refute Keyword.has_key?(result, :agent)
    end
  end

  describe "El.CLI.Start.handle_find_daemon_for_start/3" do
    setup do
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil} end)
      :ok
    end

    test "renders boxed output with name in first row" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      assert output =~ "name:  session"
    end

    test "renders boxed output with agent when present in opts" do
      expect(El.MockEl, :start, fn :session, [agent: "kent"] -> :ok end)
      expect(El.MockSessionApi, :ask, fn :session, "who are you?" -> "response" end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [agent: "kent"], El.MockEl)
        end)

      assert output =~ "agent: kent"
    end

    test "renders boxed output with model when present in opts" do
      expect(El.MockEl, :start, fn :session, [model: "opus"] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [model: "opus"], El.MockEl)
        end)

      assert output =~ "model: opus"
    end

    test "renders boxed output with msgs count" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 5, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      assert output =~ "msgs:  5"
    end

    test "renders boxed output with prompt when present" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      assert output =~ "> who are you?"
    end

    test "renders boxed output with response when present" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: "I am an agent", model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      assert output =~ "I am an agent"
    end

    test "omits agent row when agent not in opts" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      refute output =~ "agent:"
    end

    test "omits model row when model not in opts" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      refute output =~ "model:"
    end

    test "shows model from info when opts model is nil but info.model exists" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: "haiku", cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      assert output =~ "model: haiku"
    end

    test "omits prompt separator and prompt when last_prompt is nil" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      refute output =~ ">"
    end

    test "wraps long response using format_response" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      long_response = "I'm Dude, man. The rug that ties this whole stack together."
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: long_response, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      assert output =~ "stack together."
    end

    test "caps response at 2 lines" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      long_response = "This is a very long response that will definitely wrap across multiple lines when formatted with word awareness at 46 characters per line"
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 1, last_prompt: "who are you?", last_response: long_response, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      lines = String.split(output, "\n")
      response_lines = Enum.filter(lines, fn line -> String.contains?(line, ["definitely", "word", "awareness"]) end)
      assert length(response_lines) <= 2
    end

    test "sends ping when agent in opts" do
      stub(El.MockEl, :start, fn :session, [agent: "kent"] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, fn :session, "who are you?" -> "response" end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_for_start("session", [agent: "kent"], El.MockEl)
      end)
    end

    test "does not send ping when no agent in opts" do
      stub(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, 0, fn _, _ -> "response" end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
      end)
    end

    test "does not send ping when session has existing messages" do
      stub(El.MockEl, :start, fn :session, [agent: "kent"] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 5, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      expect(El.MockSessionApi, :ask, 0, fn _, _ -> "response" end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_for_start("session", [agent: "kent"], El.MockEl)
      end)
    end

    test "omits msgs row when messages count is zero" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      refute output =~ "msgs:"
    end

    test "renders cwd and id in two-column format on first two rows" do
      expect(El.MockEl, :start, fn :session, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: "/abcd/efgh", id: "abc123def456"} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("session", [], El.MockEl)
        end)

      assert output =~ "name:  session"
      assert output =~ "cwd: /abcd/efgh"
      assert output =~ "id: …123def456"
    end

    test "renders name with cwd in two-column first row for anom case" do
      expect(El.MockEl, :start, fn :anom, [] -> :ok end)
      stub(El.MockSessionApi, :info, fn :anom -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: "/a/b/c/d/e/f/g/h", id: "xyz789abc123"} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("anom", [], El.MockEl)
        end)

      assert output =~ "name:  anom"
      assert output =~ "cwd: …d/e/f/g/h"
      assert output =~ "id: …789abc123"
      refute output =~ "agent:"
      refute output =~ "model:"
      refute output =~ "msgs:"
    end

    test "renders agent with id in second row for agent sessions" do
      expect(El.MockEl, :start, fn :kent, [agent: "kent"] -> :ok end)
      expect(El.MockSessionApi, :ask, fn :kent, "who are you?" -> "response" end)
      stub(El.MockSessionApi, :info, fn :kent -> %{messages: 0, last_prompt: nil, last_response: nil, model: "opus", cwd: "/verylong/path/name", id: "kent1234567890"} end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_for_start("kent", [agent: "kent"], El.MockEl)
        end)

      assert output =~ "name:  kent"
      assert output =~ "cwd: …path/name"
      assert output =~ "agent: kent"
      assert output =~ "id: …234567890"
      assert output =~ "model: opus"
    end
  end

  describe "El.CLI.Start.handle_find_daemon_with_rest/4" do
    setup do
      stub(El.MockSessionApi, :info, fn :kenny -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, cwd: nil, id: nil} end)
      :ok
    end

    test "renders boxed output with agent when provided" do
      expect(El.MockEl, :start, fn :kenny, [agent: "kent"] -> :ok end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_with_rest("kenny", [agent: "kent"], [], El.MockEl)
        end)

      assert output =~ "agent: kent"
    end

    test "renders boxed output with model when agent has default model" do
      Application.put_env(:el, :agent_metadata, AgentMetadataStub)

      on_exit(fn ->
        Application.delete_env(:el, :agent_metadata)
      end)

      expect(El.MockEl, :start, fn :kenny, [agent: "kent", model: "opus"] -> :ok end)

      output =
        capture_io(fn ->
          El.CLI.Start.handle_find_daemon_with_rest("kenny", [agent: "kent", model: "opus"], [], El.MockEl)
        end)

      assert output =~ "model: opus"
    end
  end

  describe "El.CLI.Start.format_response/1" do
    test "returns empty list when nil" do
      assert El.CLI.Start.format_response(nil) == []
    end

    test "returns single-element list for short text" do
      assert El.CLI.Start.format_response("kent") == ["kent"]
    end

    test "wraps at 46 characters with word awareness" do
      text = "I'm Dude, man. The rug that ties this whole stack together."
      result = El.CLI.Start.format_response(text)

      assert result == ["I'm Dude, man. The rug that ties this whole", "stack together."]
    end

    test "caps at 2 lines maximum" do
      long_text = "This is a very long response that will definitely wrap across multiple lines when formatted with word awareness at 46 characters per line"
      result = El.CLI.Start.format_response(long_text)

      assert length(result) == 2
    end

    test "respects 46 character line width" do
      text = "I'm Dude, man. The rug that ties this whole stack together."
      result = El.CLI.Start.format_response(text)
      assert Enum.all?(result, fn line -> String.length(line) <= 46 end)
    end

    test "preserves short lines under 46 chars" do
      assert El.CLI.Start.format_response("short") == ["short"]
    end
  end

end
