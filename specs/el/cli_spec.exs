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

    test "returns start with --model flag" do
      assert El.CLI.parse_route(["my_session", "--model", "haiku"]) == :start
    end

    test "returns tell for name tell message" do
      assert El.CLI.parse_route(["session", "tell", "hello"]) == :tell
    end

    test "returns ask for name ask message" do
      assert El.CLI.parse_route(["session", "ask", "question"]) == :ask
    end

    test "returns log for name log" do
      assert El.CLI.parse_route(["session", "log"]) == :log
    end

    test "returns kill for name kill" do
      assert El.CLI.parse_route(["session", "kill"]) == :kill
    end

    test "returns kill_all for kill all" do
      assert El.CLI.parse_route(["kill", "all"]) == :kill_all
    end

    test "returns usage for invalid args" do
      assert El.CLI.parse_route(["bogus", "args", "that", "dont", "match"]) == :usage
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

    test "returns daemon with --model flag" do
      assert El.CLI.parse_route(["--daemon", "my_session", "--model", "opus"]) == :daemon
    end

    test "returns version for -v" do
      assert El.CLI.parse_route(["-v"]) == :version
    end

    test "returns version for --version" do
      assert El.CLI.parse_route(["--version"]) == :version
    end
  end

  describe "find_daemon_node/0" do
    setup do
      Mimic.copy(Node)
      :ok
    end

    test "returns not_found when daemon is not running" do
      Mimic.expect(Node, :alive?, fn -> true end)

      assert :not_found = El.CLI.find_daemon_node()
    end
  end

  describe "main/1" do
    setup do
      Mimic.copy(IO)
      Mimic.copy(System)
      :ok
    end

    test "prints version in usage message when no args" do
      Mimic.expect(IO, :puts, fn msg ->
        assert String.starts_with?(msg, "el 0.1.")
        assert String.contains?(msg, "usage:")
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main([])
    end

    test "prints version only for -v flag" do
      Mimic.expect(IO, :puts, fn msg ->
        refute String.contains?(msg, "usage:")
        assert msg =~ ~r/\d+\.\d+/
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main(["-v"])
    end

    test "prints version only for --version flag" do
      Mimic.expect(IO, :puts, fn msg ->
        refute String.contains?(msg, "usage:")
        assert msg =~ ~r/\d+\.\d+/
      end)
      Mimic.expect(System, :halt, fn 0 -> :ok end)

      El.CLI.main(["--version"])
    end
  end
end
