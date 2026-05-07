defmodule El.Session.Behaviours.Claude do
  @callback ask(pid(), String.t()) :: {String.t(), any(), any()}
  @callback ask_work(pid(), String.t(), any()) :: {String.t(), any(), any()}
  @callback start(any(), any()) :: pid() | nil
  @callback safe_reply(any(), any()) :: pid()
end
