defmodule El.PTY do
  use GenServer

  def start_link(name, cmd) do
    GenServer.start_link(__MODULE__, cmd, name: name)
  end

  def inject(name, message) do
    GenServer.cast(name, {:inject, message})
  end

  def run(name) do
    {:ok, pid} = start_link(name, "claude --dangerously-skip-permissions")
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _} -> :ok
    end
  end

  @impl true
  def init(cmd) do
    pty = Port.open({:spawn, "script -q /dev/null #{cmd}"}, [:binary, :stream, :exit_status])
    {:ok, tty_out} = :file.open(~c"/dev/tty", [:write, :binary, :raw])
    me = self()

    spawn_link(fn ->
      {:ok, tty_in} = :file.open(~c"/dev/tty", [:read, :binary, :raw])
      stdin_loop(tty_in, me)
    end)

    {:ok, %{pty: pty, tty_out: tty_out}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{pty: port} = state) do
    :file.write(state.tty_out, data)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, _}}, %{pty: port} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:stdin, data}, state) do
    Port.command(state.pty, data)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:inject, message}, %{pty: pty} = state) do
    Port.command(pty, message)
    {:noreply, state}
  end

  defp stdin_loop(tty_in, parent) do
    case :file.read(tty_in, 1) do
      {:ok, data} ->
        send(parent, {:stdin, data})
        stdin_loop(tty_in, parent)

      _ ->
        :ok
    end
  end
end
