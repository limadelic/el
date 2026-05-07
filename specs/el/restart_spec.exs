defmodule El.RestartSpec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "restart/2" do
    setup do
      stub(El.MockSessionDeletion, :delete_session_messages, fn _ -> :ok end)
      :ok
    end

    test "exits with :restart reason and resumes with session_id" do
      session_id = "abc-123-def"

      expect(El.MockRegistry, :lookup, fn El.Registry, :kent ->
        [{:pid, :meta}]
      end)

      stub(El.MockSupervisor, :terminate_child, fn El.SessionSupervisor, :pid -> :ok end)
      stub(El.MockMonitor, :wait_for_down, fn _ref, :kent, _opts -> :ok end)

      expect(El.MockSessionMeta, :lookup, fn :kent ->
        {:ok, session_id, "dude", "claude"}
      end)

      expect(El.MockRegistry, :lookup, fn El.Registry, :kent ->
        []
      end)

      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor,
                                                  %{start: {El.Session.Api, :start_link, [{:kent, opts}]}} ->
        assert Keyword.get(opts, :resume) == session_id
        assert Keyword.get(opts, :agent) == "dude"
        assert Keyword.get(opts, :model) == "claude"
        {:ok, :pid}
      end)

      opts = [
        registry: El.MockRegistry,
        supervisor: El.MockSupervisor,
        session_meta: El.MockSessionMeta,
        monitor: El.MockMonitor,
        app: El.MockSessionDeletion
      ]

      assert El.restart(:kent, opts) == :created
    end
  end
end
