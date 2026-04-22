defmodule El.PTY.Spec do
  use ExUnit.Case

  describe "init/1" do
    setup do
      Mimic.copy(Port)
      Mimic.copy(File)
      :ok
    end

    test "opens port with cmd" do
      Mimic.expect(Port, :open, fn {_, cmd}, _ ->
        assert String.ends_with?(cmd, "test_cmd")
        :mock_port
      end)

      Mimic.stub(File, :open, fn _, _ -> {:ok, :mock_file} end)

      El.PTY.init({"test_cmd", [port: Port, file: File]})
    end

    test "stores port from open" do
      Mimic.stub(Port, :open, fn _, _ -> :mock_port end)
      Mimic.stub(File, :open, fn _, _ -> {:ok, :mock_file} end)

      {:ok, state} = El.PTY.init({"cmd", [port: Port, file: File]})

      assert state.pty == :mock_port
    end

    test "opens tty with write mode" do
      Mimic.stub(Port, :open, fn _, _ -> :mock_port end)

      Mimic.expect(File, :open, fn path, opts ->
        assert path == ~c"/dev/tty" and :write in opts and :binary in opts and :raw in opts
        {:ok, :mock_file}
      end)

      El.PTY.init({"cmd", [port: Port, file: File]})
    end

    test "initializes tty_out" do
      Mimic.stub(Port, :open, fn _, _ -> :mock_port end)
      Mimic.stub(File, :open, fn _, _ -> {:ok, :mock_file} end)

      {:ok, state} = El.PTY.init({"cmd", [port: Port, file: File]})

      assert state.tty_out == :mock_file
    end

    test "stores file adapter" do
      Mimic.stub(Port, :open, fn _, _ -> :mock_port end)
      Mimic.stub(File, :open, fn _, _ -> {:ok, :mock_file} end)

      {:ok, state} = El.PTY.init({"cmd", [port: Port, file: File]})

      assert state.file == File
    end

    test "stores port adapter" do
      Mimic.stub(Port, :open, fn _, _ -> :mock_port end)
      Mimic.stub(File, :open, fn _, _ -> {:ok, :mock_file} end)

      {:ok, state} = El.PTY.init({"cmd", [port: Port, file: File]})

      assert state.port == Port
    end
  end

  describe "handle_cast/2" do
    setup do
      Mimic.copy(Port)
      {:ok, state: %{pty: :mock_port, tty_out: :mock_file, file: File, port: Port}}
    end

    test "injects message to port via command", %{state: state} do
      Mimic.expect(Port, :command, fn :mock_port, "hello" -> true end)

      El.PTY.handle_cast({:inject, "hello"}, state)
    end

    test "passes exact message bytes to port", %{state: state} do
      message = "test\n"
      Mimic.expect(Port, :command, fn :mock_port, ^message -> true end)

      El.PTY.handle_cast({:inject, message}, state)
    end

    test "returns noreply with unchanged state", %{state: state} do
      Mimic.stub(Port, :command, fn _, _ -> true end)

      {:noreply, returned} = El.PTY.handle_cast({:inject, "data"}, state)

      assert returned == state
    end
  end

  describe "handle_info/2" do
    setup do
      Mimic.copy(File)
      Mimic.copy(Port)
      {:ok, state: %{pty: :mock_port, tty_out: :mock_file, file: File, port: Port}}
    end

    test "writes port data to tty_out", %{state: state} do
      Mimic.expect(File, :write, fn :mock_file, "output" -> :ok end)

      El.PTY.handle_info({:mock_port, {:data, "output"}}, state)
    end

    test "writes exact data received from port", %{state: state} do
      data = "line1\nline2\n"
      Mimic.expect(File, :write, fn :mock_file, ^data -> :ok end)

      El.PTY.handle_info({:mock_port, {:data, data}}, state)
    end

    test "returns noreply on data message", %{state: state} do
      Mimic.stub(File, :write, fn _, _ -> :ok end)

      {:noreply, returned} = El.PTY.handle_info({:mock_port, {:data, "x"}}, state)

      assert returned == state
    end

    test "stops on exit_status message", %{state: state} do
      {:stop, :normal, returned} = El.PTY.handle_info({:mock_port, {:exit_status, 0}}, state)

      assert returned == state
    end

    test "handles stdin message by sending to port", %{state: state} do
      Mimic.expect(Port, :command, fn :mock_port, "user input" -> true end)

      El.PTY.handle_info({:stdin, "user input"}, state)
    end
  end
end
