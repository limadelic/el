defmodule El.Session.Api do
  @behaviour El.Session.Behaviours.Session

  alias El.Session.Registry

  def start_link({name, session_opts}) do
    opts = [name: Registry.via_tuple(name)]
    GenServer.start_link(El.Session, {name, session_opts}, opts)
  end

  def tell(name, message) do
    GenServer.cast(Registry.via_tuple(name), {:tell, message})
  end

  def cast_store_relay(name, message, response) do
    GenServer.cast(Registry.via_tuple(name), {:cast_store_relay, message, response})
  end

  def ask(name, message) do
    GenServer.call(Registry.via_tuple(name), {:ask, message}, :infinity)
  end

  def log(name) do
    GenServer.call(Registry.via_tuple(name), :log, :infinity)
  end

  def log(name, count) do
    GenServer.call(Registry.via_tuple(name), {:log, count}, :infinity)
  end

  def clear(name) do
    GenServer.call(Registry.via_tuple(name), :clear)
  end

  def detect_routes(text) do
    El.Session.Handlers.Router.detect_routes(text)
  end

  def alive?(name) do
    Registry.alive?(name)
  end

  def agent(name) do
    GenServer.call(Registry.via_tuple(name), :agent, 5_000)
  catch
    _ -> nil
  end

  def info(name) do
    GenServer.call(Registry.via_tuple(name), :info, 5_000)
  catch
    _, _ -> %{messages: 0, last_prompt: nil, last_response: nil, model: nil, id: nil, cwd: nil}
  end
end
