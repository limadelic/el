defmodule El.Behaviours.Registry do
  @callback lookup(term(), term()) :: term()
  @callback select(term(), term()) :: term()
end

defmodule El.Behaviours.Supervisor do
  @callback start_child(term(), term()) :: term()
  @callback terminate_child(term(), term()) :: term()
end

defmodule El.Behaviours.Session do
  @callback tell(term(), term()) :: term()
  @callback ask(term(), term()) :: term()
  @callback log(term()) :: term()
  @callback log(term(), term()) :: term()
  @callback clear(term()) :: term()
  @callback tell_ask(term(), term(), term()) :: term()
  @callback ask_tell(term(), term(), term()) :: term()
  @callback agent(term()) :: term()
  @callback info(term()) :: term()
end

defmodule El.Behaviours.App do
  @callback delete_session_messages(term()) :: term()
end

defmodule El.Behaviours.Monitor do
  @callback wait_for_down(term(), term()) :: term()
end

defmodule El.Behaviours.El do
  @callback start(term(), term()) :: term()
  @callback tell(term(), term()) :: term()
  @callback ask(term(), term()) :: term()
  @callback log(term(), term()) :: term()
  @callback clear(term()) :: term()
  @callback exit(term()) :: term()
  @callback exit_pattern(term()) :: term()
  @callback clear_pattern(term()) :: term()
  @callback log_pattern(term(), term()) :: term()
  @callback ls() :: term()
  @callback tell_ask(term(), term(), term()) :: term()
  @callback ask_tell(term(), term(), term()) :: term()
  @callback agent(term()) :: term()
end

defmodule El.Behaviours.FileSystem do
  @callback exists?(String.t()) :: boolean()
end

defmodule El.Behaviours.ClaudeCode do
  @callback stream(term(), term()) :: term()
  @callback stream(term(), term(), list()) :: term()
end

defmodule El.Behaviours.Store do
  @callback delete_ask_entry(term(), term(), term()) :: term()
  @callback store_ask_entry(term(), term()) :: term()
  @callback replace_ask(term(), term(), term(), term(), term()) :: term()
  @callback delete_message(term(), term()) :: term()
  @callback store_message(term(), term()) :: term()
end
