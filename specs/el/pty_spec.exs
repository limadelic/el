defmodule MockPort do
  def open(spawn_tuple, _opts) do
    send(self(), {:port_open, spawn_tuple})
    :mock_port
  end

  def command(port, data) do
    send(self(), {:port_command, port, data})
    true
  end
end

defmodule MockFile do
  def open(path, opts) do
    send(self(), {:file_open, path, opts})
    {:ok, :mock_file}
  end

  def write(device, data) do
    send(self(), {:file_write, device, data})
    :ok
  end

  def read(_device, _length) do
    {:error, :eof}
  end
end

defmodule El.PTY.Spec do
  use ExUnit.Case

  describe "init/1" do
    test "opens port with cmd" do
      El.PTY.init({"test_cmd", [port: MockPort, file: MockFile]})
      assert_received {:port_open, {:spawn, cmd}}
      assert String.ends_with?(cmd, "test_cmd")
    end

    test "stores port from open" do
      {:ok, state} = El.PTY.init({"cmd", [port: MockPort, file: MockFile]})
      assert state.pty == :mock_port
    end

    test "opens tty with write mode" do
      El.PTY.init({"cmd", [port: MockPort, file: MockFile]})
      assert_received {:file_open, ~c"/dev/tty", opts}
      assert :write in opts and :binary in opts and :raw in opts
    end

    test "initializes tty_out" do
      {:ok, state} = El.PTY.init({"cmd", [port: MockPort, file: MockFile]})
      assert state.tty_out == :mock_file
    end

    test "stores file adapter" do
      {:ok, state} = El.PTY.init({"cmd", [port: MockPort, file: MockFile]})
      assert state.file == MockFile
    end

    test "stores port adapter" do
      {:ok, state} = El.PTY.init({"cmd", [port: MockPort, file: MockFile]})
      assert state.port == MockPort
    end
  end

  describe "handle_cast/2" do
    setup do
      state = %{
        pty: :mock_port,
        tty_out: :mock_file,
        file: MockFile,
        port: MockPort
      }

      {:ok, state: state}
    end

    test "injects message to port via command", %{state: state} do
      El.PTY.handle_cast({:inject, "hello"}, state)
      assert_received {:port_command, :mock_port, "hello"}
    end

    test "passes exact message bytes to port", %{state: state} do
      El.PTY.handle_cast({:inject, "test\n"}, state)
      assert_received {:port_command, :mock_port, "test\n"}
    end

    test "returns noreply with unchanged state", %{state: state} do
      {:noreply, returned} = El.PTY.handle_cast({:inject, "data"}, state)
      assert returned == state
    end
  end

  describe "handle_info/2" do
    setup do
      state = %{
        pty: :mock_port,
        tty_out: :mock_file,
        file: MockFile,
        port: MockPort
      }

      {:ok, state: state}
    end

    test "writes port data to tty_out", %{state: state} do
      El.PTY.handle_info({:mock_port, {:data, "output"}}, state)
      assert_received {:file_write, :mock_file, "output"}
    end

    test "writes exact data received from port", %{state: state} do
      data = "line1\nline2\n"
      El.PTY.handle_info({:mock_port, {:data, data}}, state)
      assert_received {:file_write, :mock_file, ^data}
    end

    test "returns noreply on data message", %{state: state} do
      msg = {:mock_port, {:data, "x"}}
      {:noreply, returned} = El.PTY.handle_info(msg, state)
      assert returned == state
    end

    test "stops on exit_status message", %{state: state} do
      msg = {:mock_port, {:exit_status, 0}}
      {:stop, :normal, returned} = El.PTY.handle_info(msg, state)
      assert returned == state
    end

    test "handles stdin message by sending to port", %{state: state} do
      msg = {:stdin, "user input"}
      El.PTY.handle_info(msg, state)
      assert_received {:port_command, :mock_port, "user input"}
    end
  end
end
