defmodule El.RestartSpec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "restart/2" do
    setup do
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

      stub(El.MockSessionDeletion, :delete_session_messages, fn _ -> :ok end)

      opts = [
        registry: El.MockRegistry,
        supervisor: El.MockSupervisor,
        session_meta: El.MockSessionMeta,
        monitor: El.MockMonitor,
        app: El.MockSessionDeletion
      ]

      {:ok, session_id: session_id, restart_opts: opts}
    end

    test "restart calls Lifecycle.exit with :restart reason" do
      _session_id = "abc-123-def"

      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor,
                                                  %{start: {El.Session.Api, :start_link, [{:kent, _opts}]}} ->
        {:ok, :pid}
      end)

      opts = [
        registry: El.MockRegistry,
        supervisor: El.MockSupervisor,
        session_meta: El.MockSessionMeta,
        monitor: El.MockMonitor,
        app: El.MockSessionDeletion
      ]

      El.restart(:kent, opts)
    end

    test "restart starts session with resume from meta", context do
      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor,
                                                  %{start: {El.Session.Api, :start_link, [{:kent, opts}]}} ->
        send(self(), {:captured_resume, Keyword.get(opts, :resume)})
        {:ok, :pid}
      end)

      El.restart(:kent, context.restart_opts)
      assert_receive {:captured_resume, session_id} when session_id == context.session_id
    end

    test "restart preserves agent from meta", context do
      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor,
                                                  %{start: {El.Session.Api, :start_link, [{:kent, opts}]}} ->
        send(self(), {:captured_agent, Keyword.get(opts, :agent)})
        {:ok, :pid}
      end)

      El.restart(:kent, context.restart_opts)
      assert_receive {:captured_agent, agent} when agent == "dude"
    end

    test "restart preserves model from meta", context do
      expect(El.MockSupervisor, :start_child, fn El.SessionSupervisor,
                                                  %{start: {El.Session.Api, :start_link, [{:kent, opts}]}} ->
        send(self(), {:captured_model, Keyword.get(opts, :model)})
        {:ok, :pid}
      end)

      El.restart(:kent, context.restart_opts)
      assert_receive {:captured_model, model} when model == "claude"
    end
  end
end
