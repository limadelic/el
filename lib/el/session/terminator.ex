defmodule El.Session.Terminator do
  def handle(reason, _state) when reason in [:normal, :shutdown] do
    :ok
  end

  def handle({:shutdown, _}, _state) do
    :ok
  end

  def handle(reason, state) do
    entry = {"crash", "Session crashed", inspect(reason), %{}}
    state.store_module.store_message(state.name, entry)
    :ok
  end
end
