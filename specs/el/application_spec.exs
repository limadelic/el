defmodule El.Application.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(El.MessageStore)

    on_exit(fn ->
      Application.delete_env(:el, :message_store)
    end)

    Application.put_env(:el, :message_store, El.MessageStore)

    [
      children: El.Application.children(),
      supervisor_opts: El.Application.supervisor_opts()
    ]
  end

  test "children includes Registry", %{children: children} do
    assert {Registry, [keys: :unique, name: El.Registry]} in children
  end

  test "children includes DynamicSupervisor", %{children: children} do
    assert {DynamicSupervisor, [name: El.SessionSupervisor, max_restarts: 50, max_seconds: 60]} in children
  end

  test "children has exactly three entries", %{children: children} do
    assert length(children) == 3
  end

  test "children includes VersionWatcher", %{children: children} do
    assert El.VersionWatcher in children
  end

  test "supervisor opts strategy is one_for_one", %{supervisor_opts: opts} do
    assert opts[:strategy] == :one_for_one
  end

  test "supervisor opts names El.Supervisor", %{supervisor_opts: opts} do
    assert opts[:name] == El.Supervisor
  end

  test "supervisor opts has high max_restarts", %{supervisor_opts: opts} do
    assert opts[:max_restarts] == 100
  end

  test "supervisor opts has max_seconds for restart window", %{supervisor_opts: opts} do
    assert opts[:max_seconds] == 60
  end

  test "store_message delegates to message store" do
    name = :test_session
    entry = {"tell", "hello", "response", %{}}

    Mimic.expect(El.MessageStore, :insert, fn ^name, ^entry ->
      :ok
    end)

    assert El.Application.store_message(name, entry) == :ok
  end

  test "load_messages returns empty list when store returns empty" do
    Mimic.stub(El.MessageStore, :lookup, fn _name ->
      []
    end)

    messages = El.Application.load_messages(:new_session)
    assert messages == []
  end

  test "load_messages returns entries from store" do
    name = :test_session
    entry1 = {"tell", "msg1", "resp1", %{}}
    entry2 = {"tell", "msg2", "resp2", %{}}

    Mimic.stub(El.MessageStore, :lookup, fn _name ->
      [entry1, entry2]
    end)

    messages = El.Application.load_messages(name)
    assert messages == [entry1, entry2]
  end

  test "delete_session_messages delegates to message store" do
    name = :delete_test

    Mimic.expect(El.MessageStore, :delete, fn ^name ->
      :ok
    end)

    assert El.Application.delete_session_messages(name) == :ok
  end
end
