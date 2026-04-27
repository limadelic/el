defmodule El.Application.Spec do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Application.delete_env(:el, :message_store)
    end)

    Application.put_env(:el, :message_store, El.MessageStoreStub)

    [
      children: El.Application.children(),
      supervisor_opts: El.Application.supervisor_opts()
    ]
  end

  test "children includes Registry", %{children: children} do
    assert {Registry, [keys: :unique, name: El.Registry]} in children
  end

  test "children includes DynamicSupervisor", %{children: children} do
    opts = [name: El.SessionSupervisor, max_restarts: 50, max_seconds: 60]
    assert {DynamicSupervisor, opts} in children
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

  test "supervisor opts has high max_restarts", %{supervisor_opts: opts} do
    assert opts[:max_restarts] == 100
  end

  test "supervisor opts has max_seconds for restart window", %{supervisor_opts: opts} do
    assert opts[:max_seconds] == 60
  end

  test "store_message delegates to message store" do
    name = :test_session
    entry = {"tell", "hello", "response", %{}}

    assert El.Application.store_message(name, entry) == :ok
  end

  test "load_messages returns empty list when store returns empty" do
    messages = El.Application.load_messages(:new_session)
    assert messages == []
  end

  test "load_messages returns entries from store" do
    name = :test_session
    _entry1 = {"tell", "msg1", "resp1", %{}}
    _entry2 = {"tell", "msg2", "resp2", %{}}

    messages = El.Application.load_messages(name)
    assert messages == []
  end

  test "delete_session_messages delegates to message store" do
    name = :delete_test

    assert El.Application.delete_session_messages(name) == :ok
  end

  test "uses dev DETS path when DEV is set" do
    System.put_env("DEV", "1")
    dir = if El.CLI.dev?(), do: "~/.el/dev", else: "~/.el"
    assert dir == "~/.el/dev"
    System.delete_env("DEV")
  end

  test "uses prod DETS path when DEV is not set" do
    System.delete_env("DEV")
    dir = if El.CLI.dev?(), do: "~/.el/dev", else: "~/.el"
    assert dir == "~/.el"
  end
end
