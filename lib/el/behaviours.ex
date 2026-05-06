defmodule El.Behaviours.App do
  @callback delete_session_messages(term()) :: term()
  @callback delete_session_messages(term(), keyword()) :: term()
end

defmodule El.Behaviours.El do
  @callback start(term(), term()) :: term()
  @callback tell(term(), term()) :: term()
  @callback tell(term(), term(), term()) :: term()
  @callback ask(term(), term()) :: term()
  @callback ask(term(), term(), term()) :: term()
  @callback log(term()) :: term()
  @callback log(term(), term()) :: term()
  @callback log(term(), term(), term()) :: term()
  @callback clear(term()) :: term()
  @callback clear(term(), term()) :: term()
  @callback exit(term()) :: term()
  @callback exit(term(), term()) :: term()
  @callback exit_pattern(term()) :: term()
  @callback exit_pattern(term(), term()) :: term()
  @callback clear_pattern(term()) :: term()
  @callback clear_pattern(term(), term()) :: term()
  @callback log_pattern(term(), term()) :: term()
  @callback log_pattern(term(), term(), term()) :: term()
  @callback ls() :: term()
  @callback agent(term()) :: term()
  @callback agent(term(), term()) :: term()
end

