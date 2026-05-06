defmodule BootstrapMockStore do
  def load_messages(_name, _opts \\ []), do: []
end

defmodule BootstrapMockClaude do
  def start_link(_opts), do: {:ok, :test_pid}
end

defmodule El.Session.BootstrapSpec do
  use ExUnit.Case

  test "handle_continue/1 returns noreply tuple with updated state" do
    state = %{
      name: :test_session,
      store_module: BootstrapMockStore,
      claude_module: BootstrapMockClaude,
      claude_opts: [],
      opts: [],
      messages: [],
      claude_pid: nil
    }

    {:noreply, result_state} = El.Session.Bootstrap.handle_continue(state)

    assert result_state.claude_pid == :test_pid
  end
end
