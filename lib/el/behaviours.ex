defmodule El.Behaviours.Registry do
  @callback lookup(atom(), term()) :: [{pid(), term()}]
  @callback select(atom(), list()) :: [term()]
end

defmodule El.Behaviours.Supervisor do
  @callback start_child(atom(), term()) :: {:ok, pid()} | {:error, term()}
  @callback terminate_child(atom(), pid()) :: :ok | {:error, term()}
end

defmodule El.Behaviours.Session do
  @callback tell(atom(), binary()) :: :ok
  @callback ask(atom(), binary()) :: binary()
  @callback log(atom()) :: list()
  @callback log(atom(), integer()) :: list() | :not_found
  @callback clear(atom()) :: :ok
  @callback tell_ask(atom(), atom(), binary()) :: :ok
  @callback ask_tell(atom(), atom(), binary()) :: binary()
end

defmodule El.Behaviours.App do
  @callback delete_session_messages(atom()) :: :ok
end

defmodule El.Behaviours.Monitor do
  @callback wait_for_down(reference(), atom()) :: :ok
end
