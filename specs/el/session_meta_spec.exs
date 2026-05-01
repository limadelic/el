defmodule El.SessionMeta.Spec do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Application.delete_env(:el, :dets_backend)
    end)

    Application.put_env(:el, :dets_backend, El.DetsBackendStub)
    :ok
  end

  describe "insert/3" do
    test "stores meta tuple with name, agent, and session_id" do
      result = El.SessionMeta.insert(:test_name, "kent", "session-123")

      assert result == :ok
    end
  end

  describe "insert/4" do
    test "stores meta tuple with name, agent, session_id, and cwd" do
      result = El.SessionMeta.insert(:test_name, "kent", "session-123", "/home/dude")

      assert result == :ok
    end
  end

  describe "lookup/1" do
    test "returns not_found on miss" do
      result = El.SessionMeta.lookup(:missing_name)

      assert result == {:error, :not_found}
    end

    test "returns ok with agent and session_id on hit" do
      Application.put_env(:el, :dets_backend, DetsBackendWithSession)

      result = El.SessionMeta.lookup(:test_name)

      assert result == {:ok, "session-123", "kent"}
    end

    test "returns ok with agent, session_id, and cwd on hit with 4-tuple" do
      Application.put_env(:el, :dets_backend, DetsBackendWithSessionAndCwd)

      result = El.SessionMeta.lookup(:test_name)

      assert result == {:ok, "session-123", "kent", "/home/dude"}
    end
  end

  describe "delete/1" do
    test "removes meta tuple by name" do
      result = El.SessionMeta.delete(:test_name)

      assert result == :ok
    end
  end
end

defmodule DetsBackendWithSession do
  def delete(_table, _key), do: :ok

  def lookup(:session_meta, :test_name) do
    [{:test_name, "session-123", "kent"}]
  end

  def lookup(_table, _key), do: []

  def insert(_table, _key_entry), do: :ok

  def delete_object(_table, _key), do: :ok

  def foldl(_table, acc, _fun), do: acc
end

defmodule DetsBackendWithSessionAndCwd do
  def delete(_table, _key), do: :ok

  def lookup(:session_meta, :test_name) do
    [{:test_name, "session-123", "kent", "/home/dude"}]
  end

  def lookup(_table, _key), do: []

  def insert(_table, _key_entry), do: :ok

  def delete_object(_table, _key), do: :ok

  def foldl(_table, acc, _fun), do: acc
end
