defmodule El.CLI.NameParser.Spec do
  use ExUnit.Case

  describe "El.CLI.NameParser.split/1" do
    test "returns name and agent identical when no @ present" do
      assert El.CLI.NameParser.split("kent") == {"kent", "kent"}
    end

    test "preserves name verbatim and extracts agent prefix before first @" do
      assert El.CLI.NameParser.split("kent@el") == {"kent@el", "kent"}
    end
  end
end
