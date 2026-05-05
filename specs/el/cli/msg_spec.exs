defmodule El.CLI.Msg.Spec do
  use ExUnit.Case
  import Mox
  import ExUnit.CaptureIO

  @moduletag timeout: 5000

  setup :verify_on_exit!

  describe "dispatch/4" do
    test "calls el_module.ask with name as atom and joined message" do
      stub(El.MockEl, :ask, fn :session, "hello world", _deps -> "reply" end)
      stub(El.MockEl, :agent, fn :session, _opts -> nil end)

      capture_io(fn ->
        El.CLI.Msg.dispatch("session", ["hello", "world"], El.MockEl, [])
      end)
    end

    test "when agent_lookup returns name, uses agent name for sender" do
      stub(El.MockEl, :ask, fn :session, "hi there", _deps -> "response" end)
      stub(El.MockEl, :agent, fn :session, _opts -> "kent" end)

      output = capture_io(fn ->
        El.CLI.Msg.dispatch("session", ["hi", "there"], El.MockEl, [])
      end)

      assert output =~ "response"
    end

    test "when agent_lookup returns nil, uses fallback name for sender" do
      stub(El.MockEl, :ask, fn :session, "hello", _deps -> "reply" end)
      stub(El.MockEl, :agent, fn :session, _opts -> nil end)

      output = capture_io(fn ->
        El.CLI.Msg.dispatch("session", ["hello"], El.MockEl, [])
      end)

      assert output =~ "reply"
    end

    test "when agent_lookup throws, uses fallback name for sender" do
      stub(El.MockEl, :ask, fn :session, "test", _deps -> "result" end)
      stub(El.MockEl, :agent, fn :session, _opts -> throw :error end)

      output = capture_io(fn ->
        El.CLI.Msg.dispatch("session", ["test"], El.MockEl, [])
      end)

      assert output =~ "result"
    end
  end
end
