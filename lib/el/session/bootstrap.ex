defmodule El.Session.Bootstrap do
  @behaviour El.Behaviours.SessionBootstrap

  alias El.Session.Claude

  def handle_continue(state) do
    messages = state.store_module.load_messages(state.name, message_store: state.opts[:message_store])
    claude_pid = Claude.start(state.claude_module, state.claude_opts)
    {:noreply, %{state | claude_pid: claude_pid, messages: messages}}
  end
end
