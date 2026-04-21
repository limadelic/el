defmodule El.Spec do
  use ExUnit.Case

  describe "start/2" do
    test "returns name when starting first time" do
      result = El.start(:kent)
      assert result == :kent
    end

    test "returns name when already running" do
      result = El.start(:lisa)
      assert result == :lisa
    end

    test "accepts options" do
      result = El.start(:eric, claude_module: MockModule)
      assert result == :eric
    end
  end

  describe "tell/2" do
    test "returns ok" do
      assert El.tell(:kent, "message") == :ok
    end
  end

  describe "tell_ask/3" do
    test "returns ok" do
      assert El.tell_ask(:kent, :lisa, "message") == :ok
    end
  end

  describe "kill/1" do
    test "returns ok or not_found" do
      result = El.kill(:kent)
      assert result in [:ok, :not_found]
    end

    test "always returns ok or not_found even on error" do
      result = El.kill(:unknown)
      assert result in [:ok, :not_found]
    end
  end

  describe "ls/0" do
    test "returns list sorted alphabetically" do
      result = El.ls()
      assert is_list(result)
      assert result == Enum.sort(result)
    end

    test "contains only atoms" do
      result = El.ls()
      assert Enum.all?(result, &is_atom/1)
    end
  end

  describe "local_ls/0" do
    test "returns list of session names" do
      result = El.local_ls()
      assert is_list(result)
    end

    test "contains only atoms" do
      result = El.local_ls()
      assert Enum.all?(result, &is_atom/1)
    end
  end

  describe "local_lookup/1" do
    test "returns empty list when not found" do
      result = El.local_lookup(:does_not_exist)
      assert result == []
    end

    test "returns list" do
      result = El.local_lookup(:kent)
      assert is_list(result)
    end
  end
end
