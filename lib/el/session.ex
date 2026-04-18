defmodule El.Session do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def tell(name, message) do
    GenServer.call(via_tuple(name), {:tell, message})
  end

  def ask(name, message) do
    GenServer.call(via_tuple(name), {:ask, message})
  end

  def log(name) do
    GenServer.call(via_tuple(name), :log)
  end

  def alive?(name) do
    case Registry.lookup(El.Registry, name) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @impl true
  def init(name) do
    case ClaudeCode.start_link(name: name) do
      {:ok, claude_pid} ->
        {:ok, %{name: name, claude_pid: claude_pid, messages: []}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:tell, message}, _from, state) do
    response =
      state.claude_pid
      |> ClaudeCode.stream(message)
      |> ClaudeCode.Stream.text_content()
      |> Enum.join()

    new_state = %{state | messages: state.messages ++ [{"tell", message, response}]}
    {:reply, response, new_state}
  end

  def handle_call({:ask, message}, _from, state) do
    response =
      state.claude_pid
      |> ClaudeCode.stream(message)
      |> ClaudeCode.Stream.text_content()
      |> Enum.join()

    new_state = %{state | messages: state.messages ++ [{"ask", message, response}]}
    {:reply, response, new_state}
  end

  def handle_call(:log, _from, state) do
    {:reply, state.messages, state}
  end

  defp via_tuple(name) do
    {:via, Registry, {El.Registry, name}}
  end
end
