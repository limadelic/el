defmodule MockElModule do
  def start(_name, _opts), do: :ok
end

defmodule El.CLI.Start.Spec do
  use ExUnit.Case
  import Mox
  import ExUnit.CaptureIO

  setup_all do
    Code.ensure_loaded!(El.CLI.Start)
    :ok
  end

  setup :verify_on_exit!

  describe "start_daemon_node_for/4" do
    test "calls sleeper.sleep(:infinity)" do
      expect(El.MockSleeper, :sleep, fn :infinity -> :ok end)

      El.CLI.Start.start_daemon_node_for("test_daemon", nil, MockElModule, El.MockSleeper)
    end
  end

  describe "print_session_info/3 (exercises truncate_right_block)" do
    setup do
      stub(El.MockSessionApi, :info, fn _name_atom ->
        %{
          id: "session-id",
          model: "test-model",
          cwd: "/path/to/working/dir",
          messages: 0,
          last_prompt: nil,
          last_response: nil
        }
      end)

      :ok
    end

    test "handles right content with colon separator" do
      deps = [session_api: El.MockSessionApi]
      assert capture_io(fn ->
        El.CLI.Start.print_session_info("test", [], deps)
      end) =~ "id:"
    end

    test "handles right content without colon separator" do
      stub(El.MockSessionApi, :info, fn _name_atom ->
        %{
          id: "my-id",
          model: "test-model",
          cwd: "/path",
          messages: 0,
          last_prompt: nil,
          last_response: nil
        }
      end)

      deps = [session_api: El.MockSessionApi]
      assert capture_io(fn ->
        El.CLI.Start.print_session_info("test", [], deps)
      end) =~ "my-id"
    end
  end
end
