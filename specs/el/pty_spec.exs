defmodule El.PTYSpec do
  use ExUnit.Case

  describe "start_link/2" do
    test "returns ok tuple with pid" do
      {:ok, pid} = El.PTY.start_link(:test_pty, "true", opts())
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "registers GenServer by provided name" do
      {:ok, pid} = El.PTY.start_link(:named_test, "true", opts())
      assert GenServer.whereis(:named_test) == pid
      GenServer.stop(pid)
    end
  end

  describe "inject/2" do
    test "sends message to port via command" do
      Mox.verify_on_exit!(MockPortAdapter)

      {:ok, pid} = El.PTY.start_link(:inject_test, "cat", opts())

      Mox.allow(MockPortAdapter, self(), pid)

      Mox.expect(MockPortAdapter, :command, fn port, data ->
        assert port == :mock_port
        assert data == "hello"
        true
      end)

      El.PTY.inject(:inject_test, "hello")
      Process.sleep(50)
    end

    test "verifies command called exactly once" do
      Mox.verify_on_exit!(MockPortAdapter)

      {:ok, pid} = El.PTY.start_link(:count_test, "cat", opts())

      Mox.allow(MockPortAdapter, self(), pid)

      Mox.expect(MockPortAdapter, :command, 1, fn port, data ->
        assert port == :mock_port
        assert data == "once"
        true
      end)

      El.PTY.inject(:count_test, "once")
      Process.sleep(50)
    end
  end

  describe "run/1" do
    test "starts a PTY GenServer" do
      opts_val = opts()

      task =
        Task.async(fn ->
          El.PTY.run(:run_test, opts_val)
        end)

      Process.sleep(100)
      pid = GenServer.whereis(:run_test)
      assert is_pid(pid)

      GenServer.stop(pid)
      Task.await(task, 1000)
    end
  end

  setup do
    on_exit(fn ->
      for name <- [:test_pty, :named_test, :inject_test, :count_test, :run_test] do
        case GenServer.whereis(name) do
          pid when is_pid(pid) ->
            try do
              GenServer.stop(pid, :shutdown)
            rescue
              _ -> :ok
            end

          nil ->
            :ok
        end
      end
    end)
    :ok
  end

  defp opts do
    [file: SimpleFile, port: SimplePort]
  end
end

defmodule SimplePort do
  def open(_,_), do: :mock_port

  def command(port, data) do
    # Allow Mox to intercept command calls
    MockPortAdapter.command(port, data)
  end
end

defmodule SimpleFile do
  def open(_, _), do: {:ok, :mock_file}
  def read(_, _), do: {:error, :eof}
end
