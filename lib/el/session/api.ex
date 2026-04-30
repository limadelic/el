defmodule El.Session.Api do
  @behaviour El.Behaviours.Session

  alias El.Session.Registry

  def start_link({name, session_opts}) do
    opts = [name: Registry.via_tuple(name)]
    GenServer.start_link(El.Session, {name, session_opts}, opts)
  end

  def tell(name, message) do
    GenServer.cast(Registry.via_tuple(name), {:tell, message})
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

  def tell_ask(name, target, message) do
    GenServer.cast(Registry.via_tuple(name), {:tell_ask, target, message})
  end

  def ask_tell(name, target, message) do
    GenServer.call(Registry.via_tuple(name), {:ask_tell, target, message}, :infinity)
  end

  def detect_routes(text) do
    El.Session.Router.detect_routes(text)
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
    :error, _ -> %{messages: 0, last_prompt: nil, last_response: nil}
  end
end
