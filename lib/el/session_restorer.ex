defmodule El.SessionRestorer do
  def opts_modules(opts) do
    %{
      el: Keyword.fetch!(opts, :el_module),
      message_store: Keyword.fetch!(opts, :message_store),
      session_meta: Keyword.fetch!(opts, :session_meta)
    }
  end
end
