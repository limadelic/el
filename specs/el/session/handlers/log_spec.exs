defmodule El.Session.Handlers.Log.Spec do
  use ExUnit.Case
  alias El.Session.Handlers.Log

  test "{:log, :all} returns all messages" do
    messages = [{"type1", "msg1", "resp1", %{}}, {"type2", "msg2", "resp2", %{}}]
    assert {:reply, ^messages, _} = Log.handle_log({:log, :all}, %{messages: messages})
  end
end
