defmodule MockElModule do
  def start(_name, _opts), do: :ok
end

defmodule El.CLI.Start.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.CLI.Start)
    :ok
  end

  setup :verify_on_exit!

  describe "start_daemon_node_for/4" do
    test "calls sleeper.sleep(:infinity)" do
      expect(El.MockSleeper, :sleep, fn :infinity -> :ok end)

      El.CLI.Start.start_daemon_node_for("test_daemon", nil, MockElModule, El.MockSleeper)
    end
  end
end
