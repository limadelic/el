defmodule El.Session.LogHandlerSpec do
  use ExUnit.Case
  alias El.Session.LogHandler

  test "{:log, :all} returns all messages" do
    messages = [{"type1", "msg1", "resp1", %{}}, {"type2", "msg2", "resp2", %{}}]
    assert {:reply, ^messages, _} = LogHandler.handle_log({:log, :all}, %{messages: messages})
  end
end
