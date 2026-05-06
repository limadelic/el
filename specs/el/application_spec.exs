defmodule El.Application.Spec do
  use ExUnit.Case

  import Mox

  setup do
    original_el_module = Application.get_env(:el, :el_module)
    original_session_meta = Application.get_env(:el, :session_meta)
    original_daemon = Application.get_env(:el, :daemon)
    original_dets_backend = Application.get_env(:el, :dets_backend)
    original_file_system = Application.get_env(:el, :file_system)

    on_exit(fn ->
      Application.delete_env(:el, :message_store)
      Application.delete_env(:el, :session_meta)
      Application.delete_env(:el, :daemon)
      Application.delete_env(:el, :dets_backend)

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

      if original_daemon do
        Application.put_env(:el, :daemon, original_daemon)
      else
        Application.delete_env(:el, :daemon)
      end

      if original_dets_backend do
        Application.put_env(:el, :dets_backend, original_dets_backend)
      end

      if original_file_system do
        Application.put_env(:el, :file_system, original_file_system)
      else
        Application.delete_env(:el, :file_system)
      end
    end)

    Application.put_env(:el, :message_store, El.MessageStoreStub)
    Application.put_env(:el, :daemon, El.DaemonStub)
    Application.put_env(:el, :file_system, El.MockFileSystem)

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
    Application.put_env(:el, :dets_backend, El.DetsBackendStub)
    stub(El.MockFileSystem, :mkdir_p!, fn _path -> :ok end)
    El.Application.init_message_store(
      file_system: El.MockFileSystem,
      dets_backend: El.DetsBackendStub,
      daemon: El.DaemonStub
    )
    assert El.DetsBackendStub.insert(:session_meta, {:key, :value}) == :ok
  end

  describe "restore_sessions/0" do
    test "starts sessions from message store" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: RestoreSessionsStubEl)

      Application.put_env(:el, :message_store, RestoreSessionsStubStore)
      Application.put_env(:el, :el_module, RestoreSessionsStubEl)
      Application.put_env(:el, :session_meta, RestoreSessionsStubSessionMeta)

      El.Application.restore_sessions(
        el_module: RestoreSessionsStubEl,
        message_store: RestoreSessionsStubStore,
        session_meta: RestoreSessionsStubSessionMeta
      )

      calls = Agent.get(RestoreSessionsStubEl, & &1)
      assert Enum.reverse(calls) == [:dude, :kent]
    end

    test "passes continue: true and agent from SessionMeta.lookup on success" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: RestoreWithMetaStubEl)

      Application.put_env(:el, :message_store, RestoreWithMetaStubStore)
      Application.put_env(:el, :el_module, RestoreWithMetaStubEl)
      Application.put_env(:el, :session_meta, RestoreWithMetaStubSessionMeta)

      El.Application.restore_sessions(
        el_module: RestoreWithMetaStubEl,
        message_store: RestoreWithMetaStubStore,
        session_meta: RestoreWithMetaStubSessionMeta
      )

      calls = Agent.get(RestoreWithMetaStubEl, & &1)
      [{:dude, opts_1}, {:kent, opts_2}] = Enum.reverse(calls)
      assert Keyword.take(opts_1, [:resume, :agent, :model]) == [resume: :session_id_1, agent: "agent_ref_1", model: nil]
      assert Keyword.take(opts_2, [:resume, :agent, :model]) == [resume: :session_id_2, agent: "agent_ref_2", model: nil]
    end

    test "passes model from SessionMeta.lookup to el.start" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: RestoreWithModelStubEl)

      Application.put_env(:el, :message_store, RestoreWithModelStubStore)
      Application.put_env(:el, :el_module, RestoreWithModelStubEl)
      Application.put_env(:el, :session_meta, RestoreWithModelStubSessionMeta)

      El.Application.restore_sessions(
        el_module: RestoreWithModelStubEl,
        message_store: RestoreWithModelStubStore,
        session_meta: RestoreWithModelStubSessionMeta
      )

      calls = Agent.get(RestoreWithModelStubEl, & &1)
      [{:alice, opts_1}, {:bob, opts_2}] = Enum.reverse(calls)
      assert Keyword.take(opts_1, [:resume, :agent, :model]) == [resume: :sid_alpha, agent: "opusA", model: "opus"]
      assert Keyword.take(opts_2, [:resume, :agent, :model]) == [resume: :sid_beta, agent: "haikuB", model: "haiku"]
    end

    test "falls back to start without resume on SessionMeta.lookup error" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: RestoreFallbackStubEl)

      Application.put_env(:el, :message_store, RestoreFallbackStubStore)
      Application.put_env(:el, :el_module, RestoreFallbackStubEl)
      Application.put_env(:el, :session_meta, RestoreFallbackStubSessionMeta)

      El.Application.restore_sessions(
        el_module: RestoreFallbackStubEl,
        message_store: RestoreFallbackStubStore,
        session_meta: RestoreFallbackStubSessionMeta
      )

      calls = Agent.get(RestoreFallbackStubEl, & &1)
      [{:dude, opts_1}, {:kent, opts_2}] = Enum.reverse(calls)
      assert Keyword.take(opts_1, [:resume, :agent, :model]) == []
      assert Keyword.take(opts_2, [:resume, :agent, :model]) == []
    end

    test "warm-restart uses resume option from SessionMeta" do
      {:ok, _pid} = Agent.start_link(fn -> [] end, name: WarmupStubEl)

      Application.put_env(:el, :message_store, WarmupStubStore)
      Application.put_env(:el, :el_module, WarmupStubEl)
      Application.put_env(:el, :session_meta, WarmupStubSessionMeta)

      El.Application.restore_sessions(
        el_module: WarmupStubEl,
        message_store: WarmupStubStore,
        session_meta: WarmupStubSessionMeta
      )

      calls = Agent.get(WarmupStubEl, & &1)
      [{:start, [:dude, opts]}] = Enum.reverse(calls)
      assert Keyword.take(opts, [:resume, :agent, :model]) == [resume: :sid_1, agent: "a1", model: nil]
    end
  end

  describe "stop/1" do
    setup do
      Application.put_env(:el, :dets_backend, El.DetsBackendStub)
      :ok
    end

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

  def tell(_name, _message) do
    :ok
  end
end

defmodule RestoreSessionsStubSessionMeta do
  def lookup(_name), do: {:error, :not_found}
end

defmodule RestoreWithMetaStubStore do
  def session_names, do: [:dude, :kent]
end

defmodule RestoreWithMetaStubSessionMeta do
  def lookup(:dude), do: {:ok, :session_id_1, "agent_ref_1", nil}
  def lookup(:kent), do: {:ok, :session_id_2, "agent_ref_2", nil}
end

defmodule RestoreWithMetaStubEl do
  def start(name, opts) do
    Agent.update(__MODULE__, &[{name, opts} | &1])
  end

  def tell(_name, _message) do
    :ok
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

  def tell(_name, _message) do
    :ok
  end
end

defmodule El.DaemonStub do
  def dev?, do: false
end

defmodule WarmupStubStore do
  def session_names, do: [:dude]
end

defmodule WarmupStubSessionMeta do
  def lookup(:dude), do: {:ok, :sid_1, "a1", nil}
end

defmodule WarmupStubEl do
  def start(name, opts) do
    Agent.update(__MODULE__, &[{:start, [name, opts]} | &1])
  end

  def tell(name, message) do
    Agent.update(__MODULE__, &[{:tell, [name, message]} | &1])
  end
end

defmodule RestoreWithModelStubStore do
  def session_names, do: [:alice, :bob]
end

defmodule RestoreWithModelStubSessionMeta do
  def lookup(:alice), do: {:ok, :sid_alpha, "opusA", "opus"}
  def lookup(:bob), do: {:ok, :sid_beta, "haikuB", "haiku"}
end

defmodule RestoreWithModelStubEl do
  def start(name, opts) do
    Agent.update(__MODULE__, &[{name, opts} | &1])
  end

  def tell(_name, _message) do
    :ok
  end
end
