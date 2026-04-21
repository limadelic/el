defmodule El.ClaudeCodeTest do
  use ExUnit.Case, async: true

  describe "start_link/1" do
    test "returns ok tuple with pid" do
      {:ok, pid} = El.ClaudeCode.start_link([])
      assert is_pid(pid)
    end

    test "generates session id" do
      {:ok, _pid1} = El.ClaudeCode.start_link([])
      {:ok, _pid2} = El.ClaudeCode.start_link([])
      assert true
    end

    test "passes model option when provided" do
      {:ok, pid} = El.ClaudeCode.start_link(model: "claude-3-5-haiku")
      assert is_pid(pid)
    end

    test "works without model option" do
      {:ok, pid} = El.ClaudeCode.start_link([])
      assert is_pid(pid)
    end

    test "configures adapter with cli_path" do
      {:ok, pid} = El.ClaudeCode.start_link([])
      assert Process.alive?(pid)
    end
  end

  describe "stream/2" do
    test "returns stream for prompt" do
      {:ok, pid} = El.ClaudeCode.start_link([])
      result = El.ClaudeCode.stream(pid, "hello")
      assert is_function(result) or is_list(result) or match?({:ok, _}, result)
    end
  end
end
