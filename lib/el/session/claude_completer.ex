defmodule El.Session.ClaudeCompleter do
  @behaviour El.Session.AskCompleter

  def complete(reporter, {from, message, ref, claude_pid}, routes) do
    Task.start(fn ->
      {response, model, session_id} = El.Session.Claude.ask_work(claude_pid, message, routes)
      GenServer.cast(reporter, {:complete_ask, from, message, response, ref, model, session_id})
    end)
    :ok
  end
end
