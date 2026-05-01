defmodule El.Lifecycle.Spec do
  use ExUnit.Case, async: false
  import Mox
  setup :verify_on_exit!

  setup do
    original_session_meta = Application.get_env(:el, :session_meta)
    original_registry = Application.get_env(:el, :registry)

    on_exit(fn ->
      if original_session_meta do
        Application.put_env(:el, :session_meta, original_session_meta)
      else
        Application.delete_env(:el, :session_meta)
      end

      if original_registry do
        Application.put_env(:el, :registry, original_registry)
      else
        Application.delete_env(:el, :registry)
      end
    end)

    Application.put_env(:el, :session_meta, El.MockSessionMeta)
    Application.put_env(:el, :registry, El.MockRegistry)

    :ok
  end

  test "deletes session_meta on explicit exit" do
    expect(El.MockRegistry, :lookup, fn El.Registry, :test_session -> [] end)
    expect(El.MockApp, :delete_session_messages, fn :test_session -> :ok end)
    expect(El.MockSessionMeta, :delete, fn :test_session -> :ok end)
    stub(El.MockMonitor, :wait_for_down, fn _, _ -> :ok end)

    El.Lifecycle.exit(:test_session)
  end

  test "session_meta survives crash" do
    expect(El.MockRegistry, :lookup, fn El.Registry, :crashed_session -> [] end)
    stub(El.MockMonitor, :wait_for_down, fn _, _ -> :ok end)

    El.Lifecycle.exit(:crashed_session, :crash)

    verify!(El.MockSessionMeta)
  end
end
