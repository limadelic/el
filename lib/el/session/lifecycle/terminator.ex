defmodule El.Session.Lifecycle.Terminator do
  def handle(reason, _state) when reason in [:normal, :shutdown] do
    :ok
  end

  def handle({:shutdown, _}, _state) do
    :ok
  end

  def handle(reason, state) do
    entry = {"crash", "Session crashed", inspect(reason), %{}}
    state.store_module.store_message(state.name, entry, message_store: state.opts[:message_store])
    :ok
  end
end
