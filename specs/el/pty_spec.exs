defmodule MockFile do
  def open(_, _), do: {:ok, :mock_file}
  def write(_, _), do: :ok
  def read(_, _), do: {:error, :eof}
end

defmodule MockPort do
  def open(_, _), do: :mock_port
  def command(_, _), do: true
end

defmodule El.PTYSpec do
  use ExUnit.Case

  describe "start_link/2" do
    test "starts a GenServer and returns pid" do
      opts = [file: MockFile, port: MockPort]
      {:ok, pid} = El.PTY.start_link(:test_pty, "true", opts)

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "registers the GenServer by name" do
      opts = [file: MockFile, port: MockPort]
      {:ok, pid} = El.PTY.start_link(:named_pty, "true", opts)

      assert GenServer.whereis(:named_pty) == pid
    end

    test "initializes with port and file handles" do
      opts = [file: MockFile, port: MockPort]
      {:ok, _pid} = El.PTY.start_link(:init_pty, "true", opts)

      assert GenServer.whereis(:init_pty)
    end
  end

  describe "inject/2" do
    test "sends data cast to the GenServer" do
      opts = [file: MockFile, port: MockPort]
      {:ok, pid} = El.PTY.start_link(:inject_pty, "cat", opts)

      El.PTY.inject(:inject_pty, "hello")

      assert Process.alive?(pid)
    end
  end

  describe "run/1" do
    test "starts a PTY GenServer" do
      opts = [file: MockFile, port: MockPort]

      task =
        Task.async(fn ->
          El.PTY.run(:run_pty, opts)
        end)

      Process.sleep(100)
      pid = GenServer.whereis(:run_pty)

      assert is_pid(pid)

      GenServer.stop(pid)
      Task.await(task, 1000)
    end
  end

  setup do
    on_exit(fn ->
      for name <- [:test_pty, :named_pty, :init_pty, :inject_pty, :run_pty] do
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
end
