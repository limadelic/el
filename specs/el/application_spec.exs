defmodule El.Application.Spec do
  use ExUnit.Case

  setup do
    original_el_module = Application.get_env(:el, :el_module)
    original_session_meta = Application.get_env(:el, :session_meta)

    on_exit(fn ->
      Application.delete_env(:el, :message_store)
      Application.delete_env(:el, :session_meta)

      if original_el_module do
        Application.put_env(:el, :el_module, original_el_module)
      else
        Application.delete_env(:el, :el_module)
      end

      if original_session_meta do
        Application.put_env(:el, :session_meta, original_session_meta)
      else
        Application.delete_env(:el, :session_meta)
      end
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
    dir = if El.CLI.Daemon.dev?(), do: "~/.el/dev", else: "~/.el"
    assert dir == "~/.el/dev"
    System.delete_env("DEV")
  end

  test "uses prod DETS path when DEV is not set" do
    System.delete_env("DEV")
    dir = if El.CLI.Daemon.dev?(), do: "~/.el/dev", else: "~/.el"
    assert dir == "~/.el"
  end

  test "init_message_store opens session_meta table alongside message_store" do
    El.Application.init_message_store()
    assert :dets.info(:session_meta) != :undefined
  end

  describe "restore_sessions/0" do
    test "starts sessions from message store" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: RestoreSessionsStubEl)

      Application.put_env(:el, :message_store, RestoreSessionsStubStore)
      Application.put_env(:el, :el_module, RestoreSessionsStubEl)
      Application.put_env(:el, :session_meta, RestoreSessionsStubSessionMeta)

      El.Application.restore_sessions()

      calls = Agent.get(RestoreSessionsStubEl, & &1)
      assert Enum.reverse(calls) == [:dude, :kent]
    end

    test "passes resume: and agent from SessionMeta.lookup on success" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: RestoreWithMetaStubEl)

      Application.put_env(:el, :message_store, RestoreWithMetaStubStore)
      Application.put_env(:el, :el_module, RestoreWithMetaStubEl)
      Application.put_env(:el, :session_meta, RestoreWithMetaStubSessionMeta)

      El.Application.restore_sessions()

      calls = Agent.get(RestoreWithMetaStubEl, & &1)
      assert Enum.reverse(calls) == [
        {:dude, [resume: :session_id_1, agent: "agent_ref_1"]},
        {:kent, [resume: :session_id_2, agent: "agent_ref_2"]}
      ]
    end

    test "falls back to start without resume on SessionMeta.lookup error" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: RestoreFallbackStubEl)

      Application.put_env(:el, :message_store, RestoreFallbackStubStore)
      Application.put_env(:el, :el_module, RestoreFallbackStubEl)
      Application.put_env(:el, :session_meta, RestoreFallbackStubSessionMeta)

      El.Application.restore_sessions()

      calls = Agent.get(RestoreFallbackStubEl, & &1)
      assert Enum.reverse(calls) == [
        {:dude, []},
        {:kent, []}
      ]
    end
  end

  describe "stop/1" do
    test "closes the message store" do
      assert El.Application.stop(:ignored) == :ok
    end
  end
end

defmodule RestoreSessionsStubStore do
  def session_names, do: [:dude, :kent]
end

defmodule RestoreSessionsStubEl do
  def start(name, _opts \\ []) do
    Agent.update(__MODULE__, &[name | &1])
  end
end

defmodule RestoreSessionsStubSessionMeta do
  def lookup(_name), do: {:error, :not_found}
end

defmodule RestoreWithMetaStubStore do
  def session_names, do: [:dude, :kent]
end

defmodule RestoreWithMetaStubSessionMeta do
  def lookup(:dude), do: {:ok, :session_id_1, "agent_ref_1"}
  def lookup(:kent), do: {:ok, :session_id_2, "agent_ref_2"}
end

defmodule RestoreWithMetaStubEl do
  def start(name, opts) do
    Agent.update(__MODULE__, &[{name, opts} | &1])
  end
end

defmodule RestoreFallbackStubStore do
  def session_names, do: [:dude, :kent]
end

defmodule RestoreFallbackStubSessionMeta do
  def lookup(_name), do: {:error, :not_found}
end

defmodule RestoreFallbackStubEl do
  def start(name, opts) do
    Agent.update(__MODULE__, &[{name, opts} | &1])
  end
end
