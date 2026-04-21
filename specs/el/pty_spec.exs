defmodule El.PTY.Spec do
  use ExUnit.Case

  setup do
    Mox.set_mox_global()
    Mox.verify_on_exit!()
    :ok
  end

  setup do
    state = %{
      pty: :mock_port,
      tty_out: :mock_file,
      file: MockFileAdapter,
      port: MockPortAdapter
    }

    {:ok, state: state}
  end

  describe "init/1" do
    test "opens port with cmd" do
      Mox.expect(MockPortAdapter, :open, fn {_, cmd}, _ ->
        assert String.ends_with?(cmd, "test_cmd")
        :mock_port
      end)

      Mox.expect(MockFileAdapter, :open, fn _, _ ->
        {:ok, :mock_file}
      end)

      {:ok, state} =
        El.PTY.init({"test_cmd", [port: MockPortAdapter, file: MockFileAdapter]})

      assert state.pty == :mock_port
    end

    test "opens tty with write mode" do
      Mox.stub(MockPortAdapter, :open, fn _, _ -> :mock_port end)

      Mox.expect(MockFileAdapter, :open, fn path, opts ->
        assert path == ~c"/dev/tty" and :write in opts and :binary in opts and :raw in opts
        {:ok, :mock_file}
      end)

      El.PTY.init({"cmd", [port: MockPortAdapter, file: MockFileAdapter]})
    end

    test "initializes tty_out" do
      Mox.stub(MockPortAdapter, :open, fn _, _ -> :mock_port end)
      Mox.stub(MockFileAdapter, :open, fn _, _ -> {:ok, :mock_file} end)

      {:ok, state} =
        El.PTY.init({"cmd", [port: MockPortAdapter, file: MockFileAdapter]})

      assert state.tty_out == :mock_file
    end

    test "stores file adapter" do
      Mox.stub(MockPortAdapter, :open, fn _, _ -> :mock_port end)
      Mox.stub(MockFileAdapter, :open, fn _, _ -> {:ok, :mock_file} end)

      {:ok, state} =
        El.PTY.init({"cmd", [port: MockPortAdapter, file: MockFileAdapter]})

      assert state.file == MockFileAdapter
    end

    test "stores port adapter" do
      Mox.stub(MockPortAdapter, :open, fn _, _ -> :mock_port end)
      Mox.stub(MockFileAdapter, :open, fn _, _ -> {:ok, :mock_file} end)

      {:ok, state} =
        El.PTY.init({"cmd", [port: MockPortAdapter, file: MockFileAdapter]})

      assert state.port == MockPortAdapter
    end
  end

  describe "handle_cast/2" do
    test "injects message to port via command", %{state: state} do
      Mox.expect(MockPortAdapter, :command, fn :mock_port, "hello" ->
        true
      end)

      {:noreply, _returned_state} =
        El.PTY.handle_cast({:inject, "hello"}, state)
    end

    test "passes exact message bytes to port", %{state: state} do
      message = "test\n"

      Mox.expect(MockPortAdapter, :command, fn :mock_port, msg ->
        assert msg == message
        true
      end)

      El.PTY.handle_cast({:inject, message}, state)
    end

    test "returns noreply with unchanged state", %{state: state} do
      Mox.stub(MockPortAdapter, :command, fn _, _ -> true end)

      {:noreply, returned_state} =
        El.PTY.handle_cast({:inject, "data"}, state)

      assert returned_state == state
    end
  end

  describe "handle_info/2" do
    test "writes port data to tty_out", %{state: state} do
      Mox.expect(MockFileAdapter, :write, fn :mock_file, "output" ->
        :ok
      end)

      {:noreply, _returned_state} =
        El.PTY.handle_info({:mock_port, {:data, "output"}}, state)
    end

    test "writes exact data received from port", %{state: state} do
      data = "line1\nline2\n"

      Mox.expect(MockFileAdapter, :write, fn :mock_file, written_data ->
        assert written_data == data
        :ok
      end)

      El.PTY.handle_info({:mock_port, {:data, data}}, state)
    end

    test "returns noreply on data message", %{state: state} do
      Mox.stub(MockFileAdapter, :write, fn _, _ -> :ok end)

      {:noreply, returned_state} =
        El.PTY.handle_info({:mock_port, {:data, "x"}}, state)

      assert returned_state == state
    end

    test "stops on exit_status message", %{state: state} do
      {:stop, :normal, returned_state} =
        El.PTY.handle_info({:mock_port, {:exit_status, 0}}, state)

      assert returned_state == state
    end

    test "handles stdin message by sending to port", %{state: state} do
      Mox.expect(MockPortAdapter, :command, fn :mock_port, "user input" ->
        true
      end)

      {:noreply, _returned_state} =
        El.PTY.handle_info({:stdin, "user input"}, state)
    end
  end
end
