defmodule El.SessionTracker do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, MapSet.new(), name: __MODULE__)
  end

  def track(name) do
    GenServer.cast(__MODULE__, {:track, name})
  end

  def all do
    GenServer.call(__MODULE__, :all)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:all, _from, state) do
    {:reply, MapSet.to_list(state), state}
  end

  @impl true
  def handle_cast({:track, name}, state) do
    {:noreply, MapSet.put(state, name)}
  end
end
