defmodule El.Session.Behaviours.Session do
  @callback tell(term(), term()) :: term()
  @callback ask(term(), term()) :: term()
  @callback log(term()) :: term()
  @callback log(term(), term()) :: term()
  @callback clear(term()) :: term()
  @callback agent(term()) :: term()
  @callback info(term()) :: term()
  @callback cast_store_relay(term(), term(), term()) :: term()
  @callback alive?(term()) :: boolean()
end
