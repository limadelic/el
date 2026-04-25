defmodule El.VersionWatcher.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(Application)
    Mimic.copy(System)
    Mimic.copy(File)
    Mimic.copy(Process)
    :ok
  end

  describe "current_version/0" do
    test "returns current running app version" do
      Mimic.stub(Application, :spec, fn :el, :vsn -> ~c"1.2.3" end)

      result = El.VersionWatcher.current_version()
      assert result == "1.2.3"
    end
  end

  describe "installed_version/0" do
    test "reads version from start_erl.data file" do
      Mimic.stub(System, :get_env, fn "RELEASE_ROOT" -> "/opt/app" end)
      Mimic.stub(File, :read, fn "/opt/app/releases/start_erl.data" -> {:ok, "24.3.4.11 0.1.74"} end)

      result = El.VersionWatcher.installed_version()
      assert result == "0.1.74"
    end

    test "handles file not found" do
      Mimic.stub(System, :get_env, fn "RELEASE_ROOT" -> "/opt/app" end)
      Mimic.stub(File, :read, fn "/opt/app/releases/start_erl.data" -> {:error, :enoent} end)

      result = El.VersionWatcher.installed_version()
      assert result == :not_found
    end

    test "parses second token from start_erl.data format" do
      Mimic.stub(System, :get_env, fn "RELEASE_ROOT" -> "/home/user/release" end)
      Mimic.stub(File, :read, fn "/home/user/release/releases/start_erl.data" -> {:ok, "25.0 0.2.1"} end)

      result = El.VersionWatcher.installed_version()
      assert result == "0.2.1"
    end

    test "returns nil when RELEASE_ROOT not set" do
      Mimic.stub(System, :get_env, fn "RELEASE_ROOT" -> nil end)

      result = El.VersionWatcher.installed_version()
      assert result == :not_found
    end
  end

  describe "init/1" do
    test "returns ok with timer scheduled" do
      Mimic.expect(Process, :send_after, fn _pid, :check_version, 60_000 -> :timer_ref end)

      {:ok, state} = El.VersionWatcher.init(%{})

      assert state == %{}
      Mimic.verify!()
    end
  end

  describe "handle_info(:check_version, state)" do
    test "reschedules check_version message" do
      Mimic.stub(Process, :send_after, fn _pid, :check_version, 60_000 -> :timer_ref end)
      Mimic.stub(Application, :spec, fn :el, :vsn -> ~c"1.0.0" end)
      Mimic.stub(System, :get_env, fn _key -> nil end)

      {:noreply, state} = El.VersionWatcher.handle_info(:check_version, %{})

      assert state == %{}
    end
  end

  describe "check_for_update/0" do
    test "returns ok when versions match" do
      Mimic.stub(Application, :spec, fn :el, :vsn -> ~c"0.1.74" end)
      Mimic.stub(System, :get_env, fn "RELEASE_ROOT" -> "/opt/app" end)
      Mimic.stub(File, :read, fn "/opt/app/releases/start_erl.data" -> {:ok, "24.3.4.11 0.1.74"} end)

      result = El.VersionWatcher.check_for_update()

      assert result == :ok
    end

    test "returns ok when installed version not found" do
      Mimic.stub(Application, :spec, fn :el, :vsn -> ~c"0.1.75" end)
      Mimic.stub(System, :get_env, fn "RELEASE_ROOT" -> nil end)

      result = El.VersionWatcher.check_for_update()

      assert result == :ok
    end

    test "calls restart when versions differ" do
      test_pid = self()
      Mimic.stub(Application, :spec, fn :el, :vsn -> ~c"0.1.75" end)
      Mimic.stub(Application, :get_env, fn :el, :restart_fn, _default -> fn -> send(test_pid, :restarted) end end)
      Mimic.stub(System, :get_env, fn "RELEASE_ROOT" -> "/opt/app" end)
      Mimic.stub(File, :read, fn "/opt/app/releases/start_erl.data" -> {:ok, "24.3.4.11 0.1.74"} end)

      El.VersionWatcher.check_for_update()

      assert_received :restarted
    end
  end
end
