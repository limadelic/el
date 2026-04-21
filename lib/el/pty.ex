defmodule El.PTY do
  use GenServer

  def start_link(name, cmd, opts \\ []) do
    GenServer.start_link(__MODULE__, {cmd, opts}, name: name)
  end

  def inject(name, message) do
    GenServer.cast(name, {:inject, message})
  end

  def run(name, opts \\ []) do
    {:ok, pid} = start_link(name, "claude --dangerously-skip-permissions", opts)
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _} -> :ok
    end
  end

  @impl true
  def init({cmd, opts}) do
    file_module = Keyword.get(opts, :file, :file)
    port_module = Keyword.get(opts, :port, Port)

    pty =
      port_module.open({:spawn, "script -q /dev/null #{cmd}"}, [:binary, :stream, :exit_status])

    {:ok, tty_out} = file_module.open(~c"/dev/tty", [:write, :binary, :raw])
    me = self()

    spawn_link(fn ->
      {:ok, tty_in} = file_module.open(~c"/dev/tty", [:read, :binary, :raw])
      stdin_loop(tty_in, me, file_module)
    end)

    {:ok, %{pty: pty, tty_out: tty_out, file: file_module, port: port_module}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{pty: port, file: file_module} = state) do
    file_module.write(state.tty_out, data)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, _}}, %{pty: port} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:stdin, data}, %{pty: pty, port: port_module} = state) do
    port_module.command(pty, data)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:inject, message}, %{pty: pty, port: port_module} = state) do
    port_module.command(pty, message)
    {:noreply, state}
  end

  defp stdin_loop(tty_in, parent, file_module) do
    case file_module.read(tty_in, 1) do
      {:ok, data} ->
        send(parent, {:stdin, data})
        stdin_loop(tty_in, parent, file_module)

      _ ->
        :ok
    end
  end
end
