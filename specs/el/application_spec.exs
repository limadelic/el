defmodule El.Application.Spec do
  use ExUnit.Case

  setup do
    El.Application.init_message_store()
    :dets.delete_all_objects(:message_store)
    on_exit(fn -> :dets.close(:message_store) end)

    [
      children: El.Application.children(),
      supervisor_opts: El.Application.supervisor_opts()
    ]
  end

  test "children includes Registry", %{children: children} do
    assert {Registry, [keys: :unique, name: El.Registry]} in children
  end

  test "children includes DynamicSupervisor", %{children: children} do
    assert {DynamicSupervisor, [name: El.SessionSupervisor, max_restarts: 10, max_seconds: 30]} in children
  end

  test "children has exactly two entries", %{children: children} do
    assert length(children) == 2
  end

  test "supervisor opts strategy is one_for_one", %{supervisor_opts: opts} do
    assert opts[:strategy] == :one_for_one
  end

  test "supervisor opts names El.Supervisor", %{supervisor_opts: opts} do
    assert opts[:name] == El.Supervisor
  end

  test "store_message persists to ETS" do
    name = :test_session
    entry = {"tell", "hello", "response", %{}}
    El.Application.store_message(name, entry)

    messages = El.Application.load_messages(name)
    assert entry in messages
  end

  test "load_messages returns empty list for new session" do
    messages = El.Application.load_messages(:new_session)
    assert messages == []
  end

  test "delete_session_messages removes entries" do
    name = :delete_test
    El.Application.store_message(name, {"tell", "msg", "resp", %{}})
    El.Application.delete_session_messages(name)

    messages = El.Application.load_messages(name)
    assert messages == []
  end
end
