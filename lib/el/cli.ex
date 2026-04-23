defmodule El.CLI do
  @version (case Application.spec(:el, :vsn) do
              vsn when is_list(vsn) -> List.to_string(vsn)
              _ -> "0.1.41"
            end)

  def main(args) do
    main_impl(args)
    System.halt(0)
  end

  def dispatch(args) do
    main_impl(args)
  end

  def parse_route([]), do: :usage
  def parse_route(["-v"]), do: :version
  def parse_route(["--version"]), do: :version
  def parse_route(["ls"]), do: :ls
  def parse_route(["--daemon", _name]), do: :daemon
  def parse_route(["--daemon", _name, "--model", _model]), do: :daemon
  def parse_route(["kill", "all"]), do: :kill_all
  def parse_route([_name, "log"]), do: :log
  def parse_route([_name, "kill"]), do: :kill
  def parse_route([_name, "tell", "ask", "@" <> _target | _words]), do: :tell_ask
  def parse_route([_name, "tell" | _words]), do: :tell
  def parse_route([_name, "ask", "tell", "@" <> _target | _words]), do: :ask_tell
  def parse_route([_name, "ask" | _words]), do: :ask
  def parse_route([_name]), do: :start
  def parse_route([_name, "--model", _model | _rest]), do: :start
  def parse_route(_), do: :usage

  defp main_impl([]) do
    IO.puts(usage_message())
  end

  defp main_impl(["-v"]) do
    IO.puts(@version)
  end

  defp main_impl(["--version"]) do
    IO.puts(@version)
  end

  defp main_impl(["ls"]) do
    ensure_epmd()
    handle_ls(find_daemon_node())
  end

  defp main_impl(["--daemon", name]) do
    main_impl(["--daemon", name, "--model", ""])
  end

  defp main_impl(["--daemon", name, "--model", model]) do
    daemon_node = ensure_daemon_node()
    name_atom = String.to_atom(name)
    model_value = normalize_model(model)
    opts = start_opts(model_value)

    start_on_daemon_or_self(daemon_node, name_atom, opts)
    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end

  defp main_impl([name]) do
    {model, []} = extract_model_flag([])
    opts = start_opts(model)

    ensure_epmd()
    handle_find_daemon_for_start(find_daemon_node(), name, opts)
  end

  defp main_impl([name, "--model", model | rest]) do
    opts = start_opts(model)
    ensure_epmd()
    handle_find_daemon_with_rest(find_daemon_node(), name, opts, rest)
  end

  defp main_impl([name, "tell", "ask", "@" <> target | words]) do
    ensure_epmd()
    target_atom = String.to_atom(target)
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_tell_ask(find_daemon_node(), name_atom, target_atom, msg, name)
  end

  defp main_impl([name, "tell" | words]) do
    ensure_epmd()
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_tell(find_daemon_node(), name_atom, msg, name)
  end

  defp main_impl([name, "ask", "tell", "@" <> target | words]) do
    ensure_epmd()
    target_atom = String.to_atom(target)
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_ask_tell(find_daemon_node(), name_atom, target_atom, msg, name)
  end

  defp main_impl([name, "ask" | words]) do
    ensure_epmd()
    msg = Enum.join(words, " ")
    name_atom = String.to_atom(name)
    handle_ask(find_daemon_node(), name_atom, msg, name)
  end

  defp main_impl([name, "log"]) do
    ensure_epmd()
    name_atom = String.to_atom(name)
    handle_log(find_daemon_node(), name_atom, name)
  end

  defp main_impl([name, "kill"]) do
    ensure_epmd()
    name_atom = String.to_atom(name)
    handle_kill(find_daemon_node(), name_atom, name)
  end

  defp main_impl(["kill", "all"]) do
    :os.cmd(~c"pkill -9 beam 2>/dev/null")
    :os.cmd(~c"pkill -9 epmd 2>/dev/null")
    :timer.sleep(500)
    cleanup_stale_node(Path.expand("~/.el/daemon_node"))
    IO.puts("All sessions killed")
  end

  defp main_impl(_) do
    main_impl([])
  end

  defp extract_model_flag(args), do: {nil, args}

  defp start_opts(nil), do: []
  defp start_opts(model), do: [model: model]

  defp normalize_model("") do
    nil
  end

  defp normalize_model(model) do
    model
  end

  defp handle_ls({:ok, daemon_node}) do
    case :rpc.call(daemon_node, El, :local_ls, []) do
      {:badrpc, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)

      names ->
        Enum.each(names, fn name ->
          IO.puts(Atom.to_string(name))
        end)
    end
  end

  defp handle_ls(:not_found) do
    IO.puts(:stderr, "No sessions running. Start one: el <name>")
    System.halt(1)
  end

  defp handle_find_daemon_for_start({:ok, daemon_node}, name, opts) do
    name_atom = String.to_atom(name)
    :rpc.call(daemon_node, El, :start, [name_atom, opts])
    IO.puts("el: #{name} is up")
  end

  defp handle_find_daemon_for_start(:not_found, name, opts) do
    spawn_daemon(name, opts)
  end

  defp handle_find_daemon_with_rest({:ok, daemon_node}, name, opts, rest) do
    name_atom = String.to_atom(name)
    :rpc.call(daemon_node, El, :start, [name_atom, opts])
    continue_if_rest_present(rest, name)
  end

  defp handle_find_daemon_with_rest(:not_found, name, opts, rest) do
    spawn_daemon(name, opts)
    continue_if_rest_present(rest, name)
  end

  defp continue_if_rest_present([], _name) do
    :ok
  end

  defp continue_if_rest_present(rest, name) do
    main_impl([name | rest])
  end

  defp handle_tell_ask({:ok, daemon_node}, name_atom, target_atom, msg, _name) do
    case :rpc.call(daemon_node, El, :tell_ask, [name_atom, target_atom, msg]) do
      {:badrpc, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)

      _ ->
        :ok
    end
  end

  defp handle_tell_ask(:not_found, _name_atom, _target_atom, _msg, name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
    System.halt(1)
  end

  defp handle_tell({:ok, daemon_node}, name_atom, msg, _name) do
    case :rpc.call(daemon_node, El, :tell, [name_atom, msg]) do
      {:badrpc, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)

      _ ->
        :ok
    end
  end

  defp handle_tell(:not_found, _name_atom, _msg, name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
    System.halt(1)
  end

  defp handle_ask_tell({:ok, daemon_node}, name_atom, target_atom, msg, _name) do
    result = :rpc.call(daemon_node, El, :ask_tell, [name_atom, target_atom, msg])
    handle_rpc_result(result)
  end

  defp handle_ask_tell(:not_found, _name_atom, _target_atom, _msg, name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
    System.halt(1)
  end

  defp handle_ask({:ok, daemon_node}, name_atom, msg, _name) do
    result = :rpc.call(daemon_node, El, :ask, [name_atom, msg])
    handle_rpc_result(result)
  end

  defp handle_ask(:not_found, _name_atom, _msg, name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
    System.halt(1)
  end

  defp handle_log({:ok, daemon_node}, name_atom, _name) do
    case :rpc.call(daemon_node, El, :log, [name_atom]) do
      {:badrpc, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)

      log ->
        Enum.each(log, fn {type, message, response, _metadata} ->
          IO.puts("[#{type}] #{message}")
          IO.puts(response)
        end)
    end
  end

  defp handle_log(:not_found, _name_atom, name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
    System.halt(1)
  end

  defp handle_kill({:ok, daemon_node}, name_atom, _name) do
    case :rpc.call(daemon_node, El, :kill, [name_atom]) do
      {:badrpc, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)

      _ ->
        :ok
    end
  end

  defp handle_kill(:not_found, _name_atom, name) do
    IO.puts(:stderr, "No sessions running. Start one: el #{name}")
    System.halt(1)
  end

  defp handle_rpc_result({:badrpc, reason}) do
    IO.puts(:stderr, "Error: #{inspect(reason)}")
    System.halt(1)
  end

  defp handle_rpc_result(response) do
    IO.puts(response)
  end

  defp start_on_daemon_or_self(nil, name_atom, opts) do
    El.start(name_atom, opts)
  end

  defp start_on_daemon_or_self(daemon_node, name_atom, opts) do
    remote_or_local_start(daemon_node, name_atom, opts)
  end

  defp remote_or_local_start(daemon_node, name_atom, opts) do
    pick_local_or_remote(daemon_node == Node.self(), daemon_node, name_atom, opts)
  end

  defp pick_local_or_remote(true, _daemon_node, name_atom, opts) do
    El.start(name_atom, opts)
  end

  defp pick_local_or_remote(false, daemon_node, name_atom, opts) do
    :rpc.call(daemon_node, El, :start, [name_atom, opts])
  end

  defp ensure_daemon_node do
    ensure_epmd()
    node_already_alive_or_start()
  end

  defp node_already_alive_or_start do
    if_node_alive_finalize_else_start()
  end

  defp if_node_alive_finalize_else_start do
    node_alive_or_start(Node.alive?())
  end

  defp node_alive_or_start(true) do
    write_daemon_node()
    Node.self()
  end

  defp node_alive_or_start(false) do
    start_daemon_node_with_fallback()
  end

  defp start_daemon_node_with_fallback do
    handle_daemon_start(Node.start(:"el@127.0.0.1"))
  end

  defp handle_daemon_start({:ok, _}) do
    finalize_daemon_node()
  end

  defp handle_daemon_start({:error, {:already_started, _}}) do
    finalize_daemon_node()
  end

  defp handle_daemon_start({:error, _reason}) do
    nuke_epmd()
    retry_start_node(5)
  end

  defp finalize_daemon_node do
    Node.set_cookie(:el)
    Application.ensure_all_started(:el)
    write_daemon_node()
    Node.self()
  end

  defp find_daemon_node do
    ensure_epmd()
    process_daemon_node_file(read_daemon_node())
  end

  defp process_daemon_node_file({:ok, daemon_node}) do
    connect_if_not_alive(daemon_node)
  end

  defp process_daemon_node_file(:not_found) do
    :not_found
  end

  defp connect_if_not_alive(daemon_node) do
    alive_or_connect(Node.alive?(), daemon_node)
  end

  defp alive_or_connect(true, daemon_node) do
    {:ok, daemon_node}
  end

  defp alive_or_connect(false, _daemon_node) do
    try_connect_daemon()
  end

  defp ensure_epmd do
    start_epmd_daemon()
    :timer.sleep(100)
  end

  defp start_epmd_daemon do
    safe_epmd_start()
  end

  defp safe_epmd_start do
    run_cmd_or_ok(fn -> System.cmd("epmd", ["-daemon"], stderr_to_stdout: true) end)
  end

  defp run_cmd_or_ok(cmd_fn) do
    safe_cmd(cmd_fn)
  end

  defp safe_cmd(cmd_fn) do
    cmd_fn.()
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp nuke_epmd do
    stale_ports = get_stale_ports()
    kill_processes_on_ports(stale_ports)
    restart_epmd()
  end

  defp get_stale_ports do
    filter_el_ports(:erl_epmd.names())
  end

  defp filter_el_ports({:ok, names}) do
    names
    |> Enum.filter(fn {node_name, _port} ->
      String.starts_with?(to_string(node_name), "el")
    end)
    |> Enum.map(fn {_node_name, port} -> port end)
  end

  defp filter_el_ports(_) do
    []
  end

  defp kill_processes_on_ports(stale_ports) do
    Enum.each(stale_ports, fn port ->
      kill_process_on_port(port)
    end)
  end

  defp kill_process_on_port(port) do
    handle_lsof_result(:os.cmd(~c"lsof -ti :#{port} 2>/dev/null | head -1"))
  end

  defp handle_lsof_result([]) do
    :ok
  end

  defp handle_lsof_result(pid_str) do
    kill_pid_if_present(pid_str)
  end

  defp kill_pid_if_present(pid_str) do
    pid = pid_str |> List.to_string() |> String.trim()
    send_kill_if_pid_present(pid)
  end

  defp send_kill_if_pid_present(pid) when pid != "" do
    :os.cmd(~c"kill -9 #{pid} 2>/dev/null")
  end

  defp send_kill_if_pid_present(_pid) do
    :ok
  end

  defp restart_epmd do
    System.cmd("pkill", ["-9", "epmd"], stderr_to_stdout: true)
    :timer.sleep(500)
    System.cmd("epmd", ["-daemon"], stderr_to_stdout: true)
    :timer.sleep(200)
  end

  defp read_daemon_node do
    node_file = Path.expand("~/.el/daemon_node")
    parse_daemon_node_file(File.read(node_file))
  end

  defp parse_daemon_node_file({:ok, content}) do
    node_name = content |> String.trim() |> String.to_atom()
    {:ok, node_name}
  end

  defp parse_daemon_node_file({:error, :enoent}) do
    :not_found
  end

  defp try_connect_daemon do
    node_file = Path.expand("~/.el/daemon_node")
    connect_to_daemon_file(File.read(node_file), node_file)
  end

  defp connect_to_daemon_file({:ok, content}, node_file) do
    node_name = content |> String.trim() |> String.to_atom()
    attempt_daemon_connection(node_name, node_file)
  end

  defp connect_to_daemon_file({:error, :enoent}, _node_file) do
    :not_found
  end

  defp attempt_daemon_connection(node_name, node_file) do
    protected_daemon_connection(node_name, node_file)
  end

  defp protected_daemon_connection(node_name, node_file) do
    run_daemon_connection_with_error_handler(node_name, node_file)
  end

  defp run_daemon_connection_with_error_handler(node_name, node_file) do
    daemon_connection_safe(node_name, node_file)
  end

  defp daemon_connection_safe(node_name, node_file) do
    ensure_client_node_alive(node_file)
    connect_to_daemon(node_name, node_file)
  rescue
    _ ->
      cleanup_stale_node(node_file)
      :not_found
  catch
    :connection_failed ->
      :not_found

    _, _ ->
      cleanup_stale_node(node_file)
      :not_found
  end

  defp ensure_client_node_alive(node_file) do
    start_client_if_not_alive(Node.alive?(), node_file)
  end

  defp start_client_if_not_alive(true, _node_file) do
    :ok
  end

  defp start_client_if_not_alive(false, node_file) do
    start_client_node(node_file)
  end

  defp start_client_node(node_file) do
    client_node = :"el_client_#{System.os_time()}@127.0.0.1"
    start_task = Task.async(fn -> Node.start(client_node) end)
    final_result = wait_or_shutdown_task(start_task)
    handle_start_task_result(final_result, node_file)
  end

  defp wait_or_shutdown_task(start_task) do
    pick_task_result(Task.yield(start_task, 2000), start_task)
  end

  defp pick_task_result(result, _start_task) when result != nil do
    result
  end

  defp pick_task_result(nil, start_task) do
    Task.shutdown(start_task)
  end

  defp handle_start_task_result({:ok, {:ok, _}}, _node_file) do
    :ok
  end

  defp handle_start_task_result({:ok, {:error, {:already_started, _}}}, _node_file) do
    :ok
  end

  defp handle_start_task_result(_result, node_file) do
    cleanup_stale_node(node_file)
    throw(:connection_failed)
  end

  defp connect_to_daemon(node_name, node_file) do
    Node.set_cookie(:el)
    task = Task.async(fn -> Node.connect(node_name) end)
    final_connect_result = connect_wait_or_shutdown(task)
    handle_connect_result(final_connect_result, node_name, node_file)
  end

  defp connect_wait_or_shutdown(task) do
    pick_connect_result(Task.yield(task, 2000), task)
  end

  defp pick_connect_result(result, _task) when result != nil do
    result
  end

  defp pick_connect_result(nil, task) do
    Task.shutdown(task)
  end

  defp handle_connect_result({:ok, true}, node_name, _node_file) do
    {:ok, node_name}
  end

  defp handle_connect_result({:ok, :ignored}, node_name, _node_file) do
    {:ok, node_name}
  end

  defp handle_connect_result(_result, _node_name, node_file) do
    cleanup_stale_node(node_file)
    :not_found
  end

  defp cleanup_stale_node(node_file) do
    File.rm(node_file)
  rescue
    _ -> :ok
  end

  defp write_daemon_node do
    node_file = Path.expand("~/.el/daemon_node")
    File.mkdir_p!(Path.dirname(node_file))
    File.write!(node_file, Atom.to_string(Node.self()))
  end

  defp spawn_daemon(name, opts) do
    binary_path = get_binary_path()

    case System.get_env("RELEASE_ROOT") do
      nil ->
        spawn_daemon_escript(name, opts, binary_path)

      _root ->
        spawn_daemon_release(name, opts, binary_path)
    end
  end

  defp spawn_daemon_escript(name, opts, binary_path) do
    model_arg = build_model_arg(opts)
    log = Path.expand("~/.el/el.log")
    cmd = ~c"nohup #{binary_path} --daemon #{name}#{model_arg} >> #{log} 2>&1 &"
    :os.cmd(cmd)
    handle_poll_result(poll_daemon_ready(300), name)
  end

  defp spawn_daemon_release(name, opts, binary_path) do
    :os.cmd(~c"#{binary_path} daemon 2>&1")

    case poll_daemon_ready(300) do
      :ok ->
        {:ok, daemon_node} = find_daemon_node()
        name_atom = String.to_atom(name)
        :rpc.call(daemon_node, El, :start, [name_atom, opts])
        IO.puts("el: #{name} is up")

      :timeout ->
        IO.puts(:stderr, "el: daemon startup timeout")
        System.halt(1)
    end
  end

  defp handle_poll_result(:ok, name) do
    IO.puts("el: #{name} is up")
  end

  defp handle_poll_result(:timeout, _name) do
    IO.puts(:stderr, "el: daemon startup timeout")
    System.halt(1)
  end

  defp build_model_arg(opts) when is_list(opts) do
    find_model_arg(opts)
  end

  defp find_model_arg([{:model, model} | _rest]) do
    " --model #{model}"
  end

  defp find_model_arg([_head | rest]) do
    find_model_arg(rest)
  end

  defp find_model_arg([]) do
    ""
  end

  defp get_binary_path do
    case System.get_env("RELEASE_ROOT") do
      nil -> :escript.script_name() |> to_string()
      root -> Path.join([root, "bin", "el"])
    end
  end

  defp poll_daemon_ready(retries_left) when retries_left <= 0 do
    :timeout
  end

  defp poll_daemon_ready(retries_left) do
    check_daemon_and_retry(find_daemon_node(), retries_left)
  end

  defp check_daemon_and_retry({:ok, daemon_node}, retries_left) do
    verify_daemon_rpc(daemon_node, retries_left)
  end

  defp check_daemon_and_retry(:not_found, retries_left) do
    :timer.sleep(100)
    poll_daemon_ready(retries_left - 1)
  end

  defp verify_daemon_rpc(daemon_node, retries_left) do
    handle_daemon_rpc_call(:rpc.call(daemon_node, El, :local_ls, []), retries_left)
  end

  defp handle_daemon_rpc_call({:badrpc, _reason}, retries_left) do
    :timer.sleep(100)
    poll_daemon_ready(retries_left - 1)
  end

  defp handle_daemon_rpc_call(_result, _retries_left) do
    :ok
  end

  defp retry_start_node(retries_left) when retries_left <= 0 do
    IO.puts(:stderr, "FATAL: Cannot start el@127.0.0.1 after retries")
    System.halt(1)
  end

  defp retry_start_node(retries_left) do
    delay_ms = (6 - retries_left) * 100
    :timer.sleep(delay_ms)
    handle_node_start_result(Node.start(:"el@127.0.0.1"), retries_left)
  end

  defp handle_node_start_result({:ok, _}, _retries_left) do
    Node.set_cookie(:el)
    ensure_app_started()
    write_daemon_node()
    Node.self()
  end

  defp handle_node_start_result({:error, _reason}, retries_left) do
    retry_start_node(retries_left - 1)
  end

  defp ensure_app_started do
    handle_app_start(Application.ensure_all_started(:el))
  end

  defp handle_app_start({:ok, _}) do
    :ok
  end

  defp handle_app_start({:error, {:already_started, _}}) do
    :ok
  end

  defp usage_message do
    "el #{@version}\nusage: el ls | el <name> [--model <model>] | el <name> [--model <model>] tell <message> | el <name> [--model <model>] ask <message> | el <name> log | el <name> kill | el kill all | el --version"
  end
end
