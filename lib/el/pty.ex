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
    wait_for_process(pid)
  end

  defp wait_for_process(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _} -> :ok
    end
  end

  @impl true
  def init({cmd, opts}) do
    modules = extract_modules(opts)
    pty = open_pty(modules.port, cmd)
    setup_io(modules.file, pty, modules)
  end

  defp extract_modules(opts) do
    %{
      file: Keyword.get(opts, :file, File),
      port: Keyword.get(opts, :port, Port)
    }
  end

  defp setup_io(file_module, pty, modules) do
    {:ok, tty_out} = file_module.open(~c"/dev/tty", [:write, :binary, :raw])
    spawn_stdin_reader(file_module, self())
    {:ok, %{pty: pty, tty_out: tty_out, file: modules.file, port: modules.port}}
  end

  defp open_pty(port_module, cmd) do
    spawn_cmd = "script -q /dev/null #{cmd}"
    port_module.open({:spawn, spawn_cmd}, pty_opts())
  end

  defp pty_opts do
    [:binary, :stream, :exit_status]
  end

  defp spawn_stdin_reader(file_module, parent) do
    spawn_link(fn ->
      {:ok, tty_in} = file_module.open(~c"/dev/tty", [:read, :binary, :raw])
      stdin_loop(tty_in, parent, file_module)
    end)
  end

  @impl true
  def handle_info(
        {port, {:data, data}},
        %{pty: port, file: file_module} = state
      ) do
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
    process_stdin_read(file_module.read(tty_in, 1), tty_in, parent, file_module)
  end

  defp process_stdin_read({:ok, data}, tty_in, parent, file_module) do
    send(parent, {:stdin, data})
    stdin_loop(tty_in, parent, file_module)
  end

  defp process_stdin_read(_, _tty_in, _parent, _file_module) do
    :ok
  end
end
