defmodule El.SessionTest do
  use ExUnit.Case

  describe "detect_routes/1" do
    test "returns empty list for text without routes" do
      assert El.Session.detect_routes("hello") == []
    end

    test "returns empty list for bare @name without >" do
      assert El.Session.detect_routes("talk to @donnie about it") == []
    end

    test "detects single route" do
      assert El.Session.detect_routes("@donnie> you are out of your element") == [
               {:donnie, "you are out of your element"}
             ]
    end

    test "detects multiple routes on different lines" do
      assert El.Session.detect_routes("@donnie> hey\n@walter> sup") == [
               {:donnie, "hey"},
               {:walter, "sup"}
             ]
    end

    test "detects route with empty payload" do
      assert El.Session.detect_routes("@donnie>") == [{:donnie, ""}]
    end

    test "detects route with whitespace in payload" do
      assert El.Session.detect_routes("@donnie>   multiple words here") == [
               {:donnie, "multiple words here"}
             ]
    end

    test "ignores routes not at start of line" do
      assert El.Session.detect_routes("some text @donnie> payload") == []
    end

    test "handles multiline with mixed content" do
      text = """
      @donnie> message one
      some other text
      @walter> message two
      """

      assert El.Session.detect_routes(text) == [
               {:donnie, "message one"},
               {:walter, "message two"}
             ]
    end

    test "converts target to atom" do
      result = El.Session.detect_routes("@test_name> payload")
      assert [{:test_name, _}] = result
    end
  end
end
