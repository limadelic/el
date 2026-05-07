defmodule El.Pattern.Spec do
  use ExUnit.Case
  import Mox

  setup_all do
    Code.ensure_loaded!(El.Pattern)
    Code.ensure_loaded!(El.Behaviours.Pattern)
    :ok
  end

  setup :verify_on_exit!

  describe "El.Pattern" do
    test "declares @behaviour El.Behaviours.Pattern" do
      assert El.Behaviours.Pattern in El.Pattern.module_info(:attributes)[:behaviour] || []
    end
  end

  describe "El.Pattern.restart/2" do
    setup do
      stub(El.MockEl, :restart, fn _name, _opts -> :ok end)
      stub(El.MockSessionRegistry, :list, fn _opts -> [:agent1] end)
      :ok
    end

    test "restarts sessions matching pattern" do
      expect(El.MockEl, :restart, fn :agent1, _opts -> :ok end)

      El.Pattern.restart("agent*", el: El.MockEl, session_api: El.MockSessionApi)
    end
  end

  describe "El.Pattern.exit/2" do
    setup do
      stub(El.MockEl, :exit, fn _name, _opts -> :ok end)
      stub(El.MockSessionRegistry, :list, fn _opts -> [:agent1] end)
      :ok
    end

    test "exits sessions matching pattern" do
      expect(El.MockEl, :exit, fn :agent1, _opts -> :ok end)

      El.Pattern.exit("agent*", el: El.MockEl, session_api: El.MockSessionApi)
    end
  end

  describe "El.Pattern.clear/2" do
    setup do
      stub(El.MockEl, :clear, fn _name, _opts -> :ok end)
      stub(El.MockSessionRegistry, :list, fn _opts -> [:agent1] end)
      :ok
    end

    test "clears sessions matching pattern" do
      expect(El.MockEl, :clear, fn :agent1, _opts -> :ok end)

      El.Pattern.clear("agent*", el: El.MockEl, session_api: El.MockSessionApi)
    end
  end

  describe "El.Pattern.log/3" do
    setup do
      stub(El.MockSessionApi, :log, fn _name, _count -> [%{text: "log entry"}] end)
      stub(El.MockSessionRegistry, :list, fn _opts -> [:agent1] end)
      :ok
    end

    test "returns log entries for sessions matching pattern" do
      result = El.Pattern.log("agent*", 10, session_api: El.MockSessionApi)

      assert result == [%{text: "log entry"}]
    end
  end
end
