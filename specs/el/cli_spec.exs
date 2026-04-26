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

    test "returns clear for name clear" do
      assert El.CLI.parse_route(["session", "clear"]) == :clear
    end

    test "returns exit_all for exit all" do
      assert El.CLI.parse_route(["exit", "all"]) == :exit_all
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

    test "usage message contains el <name> exit" do
      Mimic.expect(IO, :puts, fn msg ->
        assert String.contains?(msg, "el <name> exit")
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
