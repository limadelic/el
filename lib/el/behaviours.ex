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
  @callback agent(term()) :: term()
  @callback info(term()) :: term()
  @callback cast_store_relay(term(), term(), term()) :: term()
end

defmodule El.Behaviours.App do
  @callback delete_session_messages(term()) :: term()
  @callback delete_session_messages(term(), keyword()) :: term()
end

defmodule El.Behaviours.Monitor do
  @callback wait_for_down(term(), term()) :: term()
  @callback wait_for_down(term(), term(), keyword()) :: term()
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

defmodule El.Behaviours.FileSystem do
  @callback exists?(String.t()) :: boolean()
  @callback cwd() :: String.t()
  @callback mkdir_p!(String.t()) :: :ok
end

defmodule El.Behaviours.Store do
  @callback delete_ask_entry(term(), term(), term()) :: term()
  @callback store_ask_entry(term(), term()) :: term()
  @callback replace_ask(term(), term(), term(), term(), term()) :: term()
  @callback delete_message(term(), term()) :: term()
  @callback delete_message(term(), term(), keyword()) :: term()
  @callback store_message(term(), term()) :: term()
  @callback store_message(term(), term(), keyword()) :: term()
  @callback delete_session_messages(term()) :: term()
  @callback delete_session_messages(term(), keyword()) :: term()
  @callback load_messages(term()) :: term()
  @callback load_messages(term(), keyword()) :: term()
end

defmodule El.Behaviours.Dets do
  @callback open_file(term(), term()) :: term()
  @callback close(term()) :: term()
  @callback insert(term(), term()) :: term()
  @callback lookup(term(), term()) :: term()
  @callback delete_object(term(), term()) :: term()
  @callback delete(term(), term()) :: term()
  @callback foldl(term(), term(), term()) :: term()
end

defmodule El.Behaviours.Sleeper do
  @callback sleep(integer()) :: :ok
end

defmodule El.Behaviours.NodeConnector do
  @callback connect(node()) :: boolean() | :ignored
  @callback set_cookie(atom()) :: true
end

defmodule El.Behaviours.NetKernel do
  @callback start([atom()]) :: {:ok, pid()} | {:error, term()}
end

defmodule El.Behaviours.SessionClaude do
  @callback ask(pid(), String.t()) :: {String.t(), any(), any()}
  @callback ask_work(pid(), String.t(), any()) :: {String.t(), any(), any()}
  @callback start(any(), any()) :: pid() | nil
  @callback safe_reply(any(), any()) :: pid()
end

defmodule El.Behaviours.System do
  @callback cmd(binary(), [binary()]) :: {Collectable.t(), exit_status :: non_neg_integer()}
end

defmodule El.Behaviours.GroupLeader do
  @callback open_null_device() :: pid()
  @callback close(pid()) :: :ok
  @callback get() :: pid()
  @callback set(pid(), pid()) :: true
end

defmodule El.Behaviours.MessageStore do
  @callback delete(atom()) :: :ok
  @callback delete_entry(atom(), tuple()) :: :ok
  @callback insert(atom(), tuple()) :: :ok
  @callback lookup(atom()) :: list()
  @callback session_names() :: [atom()]
  @callback close() :: :ok
end

defmodule El.Behaviours.Env do
  @callback get(String.t()) :: String.t() | nil
end

defmodule El.Behaviours.JSONDecoder do
  @callback decode(String.t()) :: {:ok, term()} | {:error, term()}
end

defmodule El.Behaviours.CardBox do
  @callback box_frame(list()) :: list()
  @callback frame_pair_row(String.t(), String.t()) :: String.t()
end

defmodule El.Behaviours.TextFormatter do
  @callback format_response(term()) :: list()
end
