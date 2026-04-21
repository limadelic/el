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
  end
end
