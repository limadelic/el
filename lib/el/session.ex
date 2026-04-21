defmodule El.Session do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def tell(name, message) do
    GenServer.cast(via_tuple(name), {:tell, message})
  end

  def ask(name, message) do
    GenServer.call(via_tuple(name), {:ask, message}, :infinity)
  end

  def log(name) do
    GenServer.call(via_tuple(name), :log)
  end

  def detect_routes(text) do
    Regex.scan(~r/^@(\w+)>\s*(.*)$/m, text, capture: :all_but_first)
    |> Enum.map(fn [target, payload] ->
      {String.to_atom(target), payload}
    end)
  end

  def alive?(name) do
    case Registry.lookup(El.Registry, name) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @impl true
  def init(name) do
    # Try to start ClaudeCode, but continue even if it fails
    # (allows Kill scenario to work without full ClaudeCode setup)
    claude_pid =
      try do
        case El.ClaudeCode.start_link([]) do
          {:ok, pid} -> pid
          {:error, _reason} -> nil
        end
      catch
        :exit, _ -> nil
        _, _ -> nil
      end

    {:ok, %{name: name, claude_pid: claude_pid, messages: []}}
  end

  @impl true
  def handle_cast({:tell, message}, state) do
    routes = detect_routes(message)

    if Enum.empty?(routes) do
      pid = self()
      claude_pid = state.claude_pid

      Task.start(fn ->
        response =
          if claude_pid do
            try do
              claude_pid
              |> El.ClaudeCode.stream(message)
              |> ClaudeCode.Stream.text_content()
              |> Enum.join()
            catch
              :exit, _ -> "(ClaudeCode unavailable)"
              _, _ -> "(ClaudeCode unavailable)"
            end
          else
            "(ClaudeCode unavailable)"
          end

        GenServer.cast(pid, {:store_tell, message, response})
      end)
    else
      for {target, payload} <- routes do
        if target != state.name do
          if El.Session.alive?(target) do
            GenServer.cast(
              via_tuple(target),
              {:store_relay, "[from #{state.name}] #{payload}", ""}
            )

            store_relay(state.name, message, "-> #{target}")
          else
            store_relay(state.name, message, "#{target} is not running")
          end
        end
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:store_tell, message, response}, state) do
    new_state = %{state | messages: state.messages ++ [{"tell", message, response, %{}}]}

    routes = detect_routes(response)

    Enum.each(routes, fn {target, payload} ->
      if target != state.name do
        if El.Session.alive?(target) do
          El.Session.tell(target, "[from #{state.name}] #{payload}")
          store_relay(state.name, response, "-> #{target}")
        else
          store_relay(state.name, response, "#{target} is not running")
        end
      end
    end)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:store_relay, message, response}, state) do
    {:noreply,
     %{state | messages: state.messages ++ [{"relay", message, response, %{from: state.name}}]}}
  end

  defp store_relay(sender_name, message, response) do
    pid = via_tuple(sender_name)
    GenServer.cast(pid, {:store_relay, message, response})
  end

  @impl true
  def handle_call({:ask, message}, _from, state) do
    routes = detect_routes(message)

    valid_routes =
      Enum.filter(routes, fn {target, _payload} -> target != state.name end)

    if Enum.empty?(valid_routes) do
      response = ask_claude(state.claude_pid, message)
      new_state = %{state | messages: state.messages ++ [{"ask", message, response, %{}}]}
      {:reply, response, new_state}
    else
      response =
        case valid_routes do
          [{target, payload}] ->
            if El.Session.alive?(target) do
              target_response = El.ask(target, "[from #{state.name}] #{payload}")
              store_relay(state.name, message, "-> #{target}")
              target_response
            else
              store_relay(state.name, message, "#{target} is not running")
              "#{target} is not running"
            end

          _ ->
            ask_claude(state.claude_pid, message)
        end

      new_state = %{state | messages: state.messages ++ [{"ask", message, response, %{}}]}
      {:reply, response, new_state}
    end
  end

  @impl true
  def handle_call(:log, _from, state) do
    {:reply, state.messages, state}
  end

  defp ask_claude(claude_pid, message) do
    if claude_pid do
      try do
        claude_pid
        |> El.ClaudeCode.stream(message)
        |> ClaudeCode.Stream.text_content()
        |> Enum.join()
      catch
        :exit, _ -> "(ClaudeCode unavailable)"
        _, _ -> "(ClaudeCode unavailable)"
      end
    else
      "(ClaudeCode unavailable)"
    end
  end

  defp via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end
end
