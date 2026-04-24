defmodule El.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(Registry)
    Mimic.copy(DynamicSupervisor)
    Mimic.copy(El.Session)
    :ok
  end

  describe "start/2" do
    test "returns name when lookup returns empty" do
      Mimic.stub(Registry, :lookup, fn El.Registry, _name -> [] end)
      Mimic.stub(DynamicSupervisor, :start_child, fn El.SessionSupervisor, _args -> {:ok, :pid} end)

      assert El.start(:kent) == :kent
    end

    test "returns name when session already exists" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :lisa -> [{:pid, :meta}] end)

      assert El.start(:lisa) == :lisa
    end

    test "passes options to supervisor" do
      opts = [claude_module: MockModule]
      Mimic.stub(Registry, :lookup, fn El.Registry, _name -> [] end)
      Mimic.expect(DynamicSupervisor, :start_child, fn El.SessionSupervisor, {El.Session, {_name, passed_opts}} ->
        assert passed_opts == opts
        {:ok, :pid}
      end)

      El.start(:eric, opts)
    end
  end

  describe "tell/2" do
    test "delegates to El.Session.tell" do
      Mimic.expect(El.Session, :tell, fn :kent, "message" -> :ok end)

      assert El.tell(:kent, "message") == :ok
    end
  end

  describe "tell_ask/3" do
    test "delegates to El.Session.tell_ask" do
      Mimic.expect(El.Session, :tell_ask, fn :kent, :lisa, "message" -> :ok end)

      assert El.tell_ask(:kent, :lisa, "message") == :ok
    end
  end

  describe "kill/1" do
    test "returns ok when session found and terminated" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :kent -> [{:pid, :meta}] end)
      Mimic.expect(DynamicSupervisor, :terminate_child, fn El.SessionSupervisor, :pid -> :ok end)

      result = El.kill(:kent)
      assert result == :ok
    end

    test "returns not_found when session not running" do
      Mimic.stub(Registry, :lookup, fn El.Registry, :unknown -> [] end)

      assert El.kill(:unknown) == :not_found
    end

    test "rescues errors and returns ok" do
      Mimic.stub(Registry, :lookup, fn El.Registry, _name -> [{:pid, :meta}] end)
      Mimic.stub(DynamicSupervisor, :terminate_child, fn _, _ -> raise "error" end)

      result = El.kill(:kent)
      assert result == :ok
    end
  end

  describe "ls/0" do
    test "returns sorted list from Registry.select" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [:zeta, :alpha, :beta] end)

      result = El.ls()
      assert result == [:alpha, :beta, :zeta]
    end

    test "returns empty list when no sessions" do
      Mimic.stub(Registry, :select, fn El.Registry, _pattern -> [] end)

      assert El.ls() == []
    end
  end

end
