defmodule El.CLI.Spec do
  use ExUnit.Case, async: true

  describe "parse_route/1" do
    test "returns usage when no args" do
      assert El.CLI.parse_route([]) == :usage
    end

    test "returns ls for ls command" do
      assert El.CLI.parse_route(["ls"]) == :ls
    end

    test "returns start for single session name" do
      assert El.CLI.parse_route(["my_session"]) == :start
    end

    test "returns start with -m flag" do
      assert El.CLI.parse_route(["my_session", "-m", "haiku"]) == :start
    end

    test "returns msg for name word message" do
      assert El.CLI.parse_route(["session", "hello"]) == :msg
    end

    test "returns msg for name multiple words" do
      assert El.CLI.parse_route(["session", "hello", "world", "foo"]) == :msg
    end

    test "routes arbitrary args to msg" do
      assert El.CLI.parse_route(["bogus", "args"]) == :msg
    end

    test "returns log for name log" do
      assert El.CLI.parse_route(["session", "log"]) == :log
    end

    test "returns log_n for name log with number" do
      assert El.CLI.parse_route(["session", "log", "5"]) == :log_n
    end

    test "returns log_n for name log all" do
      assert El.CLI.parse_route(["session", "log", "all"]) == :log_n
    end

    test "returns exit for name exit" do
      assert El.CLI.parse_route(["session", "exit"]) == :exit
    end

    test "returns exit_all for exit" do
      assert El.CLI.parse_route(["exit"]) == :exit_all
    end

    test "returns exit for dud* exit" do
      assert El.CLI.parse_route(["dud*", "exit"]) == :exit
    end

    test "returns clear for name clear" do
      assert El.CLI.parse_route(["session", "clear"]) == :clear
    end

    test "returns tell_ask for name tell ask @target message" do
      assert El.CLI.parse_route(["session", "tell", "ask", "@other", "hello"]) == :tell_ask
    end

    test "returns ask_tell for name ask tell @target message" do
      assert El.CLI.parse_route(["session", "ask", "tell", "@other", "hello"]) == :ask_tell
    end

    test "returns daemon for --daemon flag" do
      assert El.CLI.parse_route(["--daemon", "my_session"]) == :daemon
    end

    test "returns daemon with -m flag" do
      assert El.CLI.parse_route(["--daemon", "my_session", "-m", "opus"]) == :daemon
    end

    test "returns version for -v" do
      assert El.CLI.parse_route(["-v"]) == :version
    end

    test "returns usage for args starting with --" do
      assert El.CLI.parse_route(["--nonsense"]) == :usage
    end

    test "returns usage for args starting with -" do
      assert El.CLI.parse_route(["-x"]) == :usage
    end

  end

  describe "execute/2" do
    setup do
      Mimic.copy(El)
      Mimic.copy(IO)
      :ok
    end

    test "execute :log_n with number calls El.log with count" do
      Mimic.expect(El, :log, fn :session, 5 -> [] end)

      El.CLI.execute(:log_n, ["session", "log", "5"])
    end

    test "execute :log_n with number prints result" do
      Mimic.expect(El, :log, fn :session, 5 -> [{"ask", "hello", "world", %{}}] end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "[ask] hello"
      end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "world"
      end)

      El.CLI.execute(:log_n, ["session", "log", "5"])
    end

    test "execute :log_n with 'all' calls El.log with :all" do
      Mimic.expect(El, :log, fn :session, :all -> [] end)

      El.CLI.execute(:log_n, ["session", "log", "all"])
    end

    test "execute :log_n with 'all' prints result" do
      Mimic.expect(El, :log, fn :session, :all -> [{"tell", "goodbye", "see ya", %{}}] end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "[tell] goodbye"
      end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "see ya"
      end)

      El.CLI.execute(:log_n, ["session", "log", "all"])
    end

    test "execute :log calls El.log with count 1" do
      Mimic.expect(El, :log, fn :session, 1 -> [] end)

      El.CLI.execute(:log, ["session", "log"])
    end

    test "execute :log prints result" do
      Mimic.expect(El, :log, fn :session, 1 -> [{"ask", "hi", "reply", %{}}] end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "[ask] hi"
      end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "reply"
      end)

      El.CLI.execute(:log, ["session", "log"])
    end

    test "execute :clear calls El.clear with name" do
      Mimic.expect(El, :clear, fn :session -> "cleared" end)
      Mimic.stub(IO, :puts, fn _ -> :ok end)

      El.CLI.execute(:clear, ["session", "clear"])
    end

    test "execute :clear handles not_found" do
      Mimic.stub(El, :clear, fn _ -> :not_found end)
      Mimic.expect(IO, :puts, fn :stderr, msg ->
        assert String.contains?(msg, "No sessions running")
      end)

      El.CLI.execute(:clear, ["session", "clear"])
    end

    test "execute :exit_all calls El.exit(:all)" do
      Mimic.expect(El, :exit, fn :all -> :ok end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "exited all"
      end)

      El.CLI.execute(:exit_all, ["exit"])
    end

    test "execute :exit with glob pattern calls El.exit_pattern" do
      Mimic.expect(El, :exit_pattern, fn "dud*" -> :ok end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "exited sessions matching dud*"
      end)

      El.CLI.execute(:exit, ["dud*", "exit"])
    end

    test "execute :exit with session name calls El.exit" do
      Mimic.expect(El, :exit, fn :session -> :ok end)
      Mimic.stub(IO, :puts, fn _ -> :ok end)

      El.CLI.execute(:exit, ["session", "exit"])
    end

    test "execute :clear with glob pattern calls El.clear_pattern" do
      Mimic.expect(El, :clear_pattern, fn "dud*" -> :ok end)
      Mimic.expect(IO, :puts, fn msg ->
        assert msg == "cleared sessions matching dud*"
      end)

      El.CLI.execute(:clear, ["dud*", "clear"])
    end

    test "execute :clear with session name calls El.clear" do
      Mimic.expect(El, :clear, fn :session -> "cleared" end)
      Mimic.stub(IO, :puts, fn _ -> :ok end)

      El.CLI.execute(:clear, ["session", "clear"])
    end

    test "execute :log with glob pattern calls El.log_pattern" do
      Mimic.expect(El, :log_pattern, fn "dud*", 1 -> [] end)
      Mimic.stub(IO, :puts, fn _ -> :ok end)

      El.CLI.execute(:log, ["dud*", "log"])
    end

    test "execute :log with session name calls El.log" do
      Mimic.expect(El, :log, fn :session, 1 -> [] end)

      El.CLI.execute(:log, ["session", "log"])
    end

    test "execute :log_n with glob pattern calls El.log_pattern" do
      Mimic.expect(El, :log_pattern, fn "dud*", 5 -> [] end)
      Mimic.stub(IO, :puts, fn _ -> :ok end)

      El.CLI.execute(:log_n, ["dud*", "log", "5"])
    end

    test "execute :log_n with session name calls El.log" do
      Mimic.expect(El, :log, fn :session, 5 -> [] end)

      El.CLI.execute(:log_n, ["session", "log", "5"])
    end
  end


  describe "daemon spawning" do
    setup do
      Mimic.copy(System)
      Mimic.copy(Node)
      Mimic.copy(IO)
      Mimic.copy(El)
      :ok
    end

    test "spawn_daemon uses absolute path for script" do
      Mimic.expect(System, :cmd, fn
        "epmd", ["-daemon"] ->
          {"", 0}

        "sh", ["-c", cmd] ->
          send(self(), {:cmd, cmd})
          {"", 0}
      end)

      Mimic.stub(Node, :connect, fn _ -> false end)
      Mimic.stub(IO, :puts, fn _ -> :ok end)
      Mimic.stub(System, :halt, fn _ -> :ok end)

      El.CLI.main([])

      receive do
        {:cmd, cmd} ->
          script = cmd |> String.split(" ") |> List.first()
          assert Path.absolute?(script)

        after 100 ->
          :ok
      end
    end

    test "uses el_dev@127.0.0.1 when DEV is set" do
      Mimic.copy(System)
      Mimic.stub(System, :get_env, fn "DEV" -> "1" end)

      assert El.CLI.daemon_node() == :"el_dev@127.0.0.1"
    end

    test "uses el@127.0.0.1 when DEV is not set" do
      Mimic.copy(System)
      Mimic.stub(System, :get_env, fn "DEV" -> nil end)

      assert El.CLI.daemon_node() == :"el@127.0.0.1"
    end

  end

  describe "main/1" do
    setup do
      Mimic.copy(IO)
      Mimic.copy(System)
      :ok
    end

    test "version starts with el v0.1." do
      Mimic.expect(IO, :puts, fn msg ->
        assert String.starts_with?(msg, "el v0.1.")
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main([])
    end

    test "usage message contains el ls" do
      Mimic.expect(IO, :puts, fn msg ->
        assert String.contains?(msg, "el ls")
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main([])
    end

    test "usage message contains el -v" do
      Mimic.expect(IO, :puts, fn msg ->
        assert String.contains?(msg, "el -v")
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main([])
    end

    test "usage message contains el exit" do
      Mimic.expect(IO, :puts, fn msg ->
        assert String.contains?(msg, "el exit")
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main([])
    end

    test "usage message contains el <name|glob> exit" do
      Mimic.expect(IO, :puts, fn msg ->
        assert String.contains?(msg, "el <name|glob> exit")
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main([])
    end

    test "version does not contain usage info" do
      Mimic.expect(IO, :puts, fn msg ->
        refute String.contains?(msg, "el ls")
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main(["-v"])
    end

    test "version matches version format" do
      Mimic.expect(IO, :puts, fn msg ->
        assert msg =~ ~r/\d+\.\d+/
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main(["-v"])
    end

  end
end
