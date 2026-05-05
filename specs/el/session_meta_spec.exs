defmodule El.SessionMeta.Spec do
  use ExUnit.Case

  describe "insert/4" do
    test "stores meta tuple with name, agent, session_id, and model" do
      result = El.SessionMeta.insert(:test_name, "kent", "session-123", "haiku", dets_backend: El.DetsBackendStub)

      assert result == :ok
    end

    test "persists model alongside agent and session_id" do
      El.SessionMeta.insert(:foo, "donny", "abc-123", "haiku", dets_backend: ModelCapturingBackend)

      received = Application.get_env(:el, :captured_tuple)
      assert received == {:foo, "abc-123", "donny", "haiku"}
    end
  end

  describe "lookup/1" do
    test "returns not_found on miss" do
      result = El.SessionMeta.lookup(:missing_name, dets_backend: El.DetsBackendStub)

      assert result == {:error, :not_found}
    end

    test "returns ok with agent and session_id on hit" do
      result = El.SessionMeta.lookup(:test_name, dets_backend: DetsBackendWithSession)

      assert result == {:ok, "session-123", "kent", nil}
    end
  end

  describe "delete/1" do
    test "removes meta tuple by name" do
      result = El.SessionMeta.delete(:test_name, dets_backend: El.DetsBackendStub)

      assert result == :ok
    end
  end
end

defmodule DetsBackendWithSession do
  def delete(_table, _key), do: :ok

  def lookup(:session_meta, :test_name) do
    [{:test_name, "session-123", "kent", nil}]
  end

  def lookup(_table, _key), do: []

  def insert(_table, _key_entry), do: :ok

  def delete_object(_table, _key), do: :ok

  def foldl(_table, acc, _fun), do: acc
end

defmodule ModelCapturingBackend do
  def insert(_table, tuple) do
    Application.put_env(:el, :captured_tuple, tuple)
    :ok
  end

  def delete(_table, _key), do: :ok
  def lookup(_table, _key), do: []
  def delete_object(_table, _key), do: :ok
  def foldl(_table, acc, _fun), do: acc
end
