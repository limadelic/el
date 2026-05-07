defmodule El.Lifecycle.Spec do
  use ExUnit.Case, async: false
  import Mox
  setup :verify_on_exit!

  setup_all do
    Code.ensure_loaded!(El.Lifecycle)
    Code.ensure_loaded!(El.Session.Registry)
    :ok
  end

  test "deletes session_meta on explicit exit" do
    expect(El.MockRegistry, :lookup, fn El.Registry, :test_session -> [] end)
    expect(El.MockSessionDeletion, :delete_session_messages, fn :test_session, _opts -> :ok end)
    expect(El.MockSessionMeta, :delete, fn :test_session -> :ok end)
    stub(El.MockMonitor, :wait_for_down, fn _, _, _ -> :ok end)

    El.Lifecycle.exit(:test_session, :normal, [
      registry: El.MockRegistry,
      app: El.MockSessionDeletion,
      session_meta: El.MockSessionMeta,
      monitor: El.MockMonitor
    ])
  end

  test "session_meta survives crash" do
    expect(El.MockRegistry, :lookup, fn El.Registry, :crashed_session -> [] end)
    stub(El.MockMonitor, :wait_for_down, fn _, _, _ -> :ok end)

    El.Lifecycle.exit(:crashed_session, :crash, [
      registry: El.MockRegistry,
      session_meta: El.MockSessionMeta,
      monitor: El.MockMonitor
    ])

    verify!(El.MockSessionMeta)
  end

  test "session_meta survives restart" do
    expect(El.MockRegistry, :lookup, fn El.Registry, :restarted_session -> [] end)
    stub(El.MockMonitor, :wait_for_down, fn _, _, _ -> :ok end)

    El.Lifecycle.exit(:restarted_session, :restart, [
      registry: El.MockRegistry,
      session_meta: El.MockSessionMeta,
      monitor: El.MockMonitor
    ])

    verify!(El.MockSessionMeta)
  end
end
