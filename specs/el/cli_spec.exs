defmodule El.CLI.Spec do
  use ExUnit.Case, async: false

  describe "parse_route/1 determines which command to execute" do
    test "empty args identifies usage route" do
      assert El.CLI.parse_route([]) == :usage
    end

    test "ls identifies list sessions route" do
      assert El.CLI.parse_route(["ls"]) == :ls
    end

    test "single name identifies start session route" do
      assert El.CLI.parse_route(["my_session"]) == :start
    end

    test "name with --model flag identifies start with options route" do
      assert El.CLI.parse_route(["my_session", "--model", "haiku"]) == :start
    end

    test "name tell message identifies tell route" do
      assert El.CLI.parse_route(["session", "tell", "hello"]) == :tell
    end

    test "name ask message identifies ask route" do
      assert El.CLI.parse_route(["session", "ask", "question"]) == :ask
    end

    test "name log identifies log route" do
      assert El.CLI.parse_route(["session", "log"]) == :log
    end

    test "name kill identifies kill route" do
      assert El.CLI.parse_route(["session", "kill"]) == :kill
    end

    test "kill all identifies kill all route" do
      assert El.CLI.parse_route(["kill", "all"]) == :kill_all
    end

    test "invalid args defaults to usage" do
      assert El.CLI.parse_route(["bogus", "args", "that", "dont", "match"]) == :usage
    end

    test "name tell ask @target message identifies tell_ask route" do
      assert El.CLI.parse_route(["session", "tell", "ask", "@other", "hello"]) == :tell_ask
    end

    test "name ask tell @target message identifies ask_tell route" do
      assert El.CLI.parse_route(["session", "ask", "tell", "@other", "hello"]) == :ask_tell
    end

    test "daemon flag identifies daemon route" do
      assert El.CLI.parse_route(["--daemon", "my_session"]) == :daemon
    end

    test "daemon flag with model identifies daemon route" do
      assert El.CLI.parse_route(["--daemon", "my_session", "--model", "opus"]) == :daemon
    end
  end
end
