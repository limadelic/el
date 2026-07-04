defmodule El.CLI.Info.Spec do
  use ExUnit.Case
  import Mox
  import ExUnit.CaptureIO

  setup :verify_on_exit!

  describe "El.CLI.Info.execute/2" do
    test "outputs session name when alive" do
      stub(El.MockSessionApi, :alive?, fn :session -> true end)
      stub(El.MockSessionApi, :info, fn :session -> %{messages: 2, last_prompt: "who?", last_response: "me", model: "haiku", cwd: nil, id: nil} end)
      stub(El.MockSessionApi, :agent, fn :session -> nil end)

      output =
        capture_io(fn ->
          El.CLI.Info.execute(["session"], [session_api: El.MockSessionApi])
        end)

      assert output =~ "session"
    end

    test "outputs usage when session not alive" do
      stub(El.MockSessionApi, :alive?, fn :session -> false end)

      output =
        capture_io(fn ->
          El.CLI.Info.execute(["session"], [session_api: El.MockSessionApi])
        end)

      assert output =~ "el ls"
    end
  end

  describe "El.CLI.Info.execute_json/2" do
    test "outputs JSON for live session" do
      stub(El.MockSessionApi, :alive?, fn :live -> true end)
      stub(El.MockSessionApi, :info, fn :live ->
        %{id: "abc-123", model: "sonnet", cwd: "/work", messages: 3, last_prompt: nil, last_response: nil}
      end)
      stub(El.MockSessionApi, :agent, fn :live -> "researcher" end)

      output =
        capture_io(fn ->
          El.CLI.Info.execute_json(["live"], [session_api: El.MockSessionApi])
        end)

      decoded = Jason.decode!(String.trim(output))
      assert decoded["name"] == "live"
      assert decoded["alive"] == true
    end
  end
end
