defmodule MockElModule do
  def start(_name, _opts), do: :ok
end

defmodule El.CLI.Start.Spec do
  use ExUnit.Case
  import Mox
  import ExUnit.CaptureIO

  setup_all do
    Code.ensure_loaded!(El.CLI.Start)
    Code.ensure_loaded!(El.CLI.Start.CardBox)
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

  describe "handle_find_daemon_for_start/4" do
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
      stub(El.MockGroupLeader, :open_null_device, fn -> :null_device end)
      stub(El.MockGroupLeader, :get, fn -> :original_leader end)
      stub(El.MockGroupLeader, :set, fn _, _ -> true end)
      stub(El.MockGroupLeader, :close, fn _ -> :ok end)

      %{
        base_deps: [
          session_api: El.MockSessionApi,
          group_leader: El.MockGroupLeader
        ]
      }
    end

    test "invokes ping_for_session_id when no agent in opts", %{base_deps: deps} do
      expect(El.MockSessionApi, :probe_ask, fn _, _ -> "test response" end)
      expect(El.MockSessionApi, :agent, fn _ -> nil end)
      opts = []
      expect(El.MockSessionApi, :info, 2, fn _name_atom ->
        %{
          id: "session-id",
          model: "test-model",
          cwd: "/path/to/working/dir",
          messages: 0,
          last_prompt: nil,
          last_response: nil
        }
      end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_for_start("test", opts, MockElModule, deps)
      end)
    end
  end

  describe "handle_find_daemon_with_rest/5" do
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
      stub(El.MockGroupLeader, :open_null_device, fn -> :null_device end)
      stub(El.MockGroupLeader, :get, fn -> :original_leader end)
      stub(El.MockGroupLeader, :set, fn _, _ -> true end)
      stub(El.MockGroupLeader, :close, fn _ -> :ok end)

      %{
        base_deps: [
          session_api: El.MockSessionApi,
          group_leader: El.MockGroupLeader
        ]
      }
    end

    test "invokes ping_for_session_id when agent in opts", %{base_deps: deps} do
      expect(El.MockSessionApi, :ask, fn _, _ -> "test response" end)
      expect(El.MockSessionApi, :agent, fn _ -> "kent" end)
      opts = [agent: :some_agent]
      expect(El.MockSessionApi, :info, 2, fn _name_atom ->
        %{
          id: "session-id",
          model: "test-model",
          cwd: "/path/to/working/dir",
          messages: 0,
          last_prompt: nil,
          last_response: nil
        }
      end)

      capture_io(fn ->
        El.CLI.Start.handle_find_daemon_with_rest("test", opts, [], MockElModule, deps)
      end)
    end
  end
end
