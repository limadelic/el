defmodule El.MessageStore.Behaviours.Dets do
  @callback open_file(term(), term()) :: term()
  @callback close(term()) :: term()
  @callback insert(term(), term()) :: term()
  @callback lookup(term(), term()) :: term()
  @callback delete_object(term(), term()) :: term()
  @callback delete(term(), term()) :: term()
  @callback foldl(term(), term(), term()) :: term()
end
