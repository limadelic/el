defmodule DetsBackendWithEntries do
  def delete_object(_table, _key), do: :ok

  def foldl(_table, acc, fun) do
    acc = fun.({:dude, {"ask", "hi", "hello", %{}}}, acc)
    fun.({:kent, {"tell", "yo", "", %{}}}, acc)
  end
end

defmodule El.MessageStore.Spec do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Application.delete_env(:el, :dets_backend)
    end)

    Application.put_env(:el, :dets_backend, El.DetsBackendStub)
    :ok
  end

  describe "delete_entry/2" do
    test "calls dets.delete_object with correct arguments" do
      name = :test_entry
      entry = {"tell", "hello", "response", %{}}

      result = El.MessageStore.delete_entry(name, entry)

      assert result == :ok
    end
  end

  describe "session_names/0" do
    test "returns empty list when no sessions" do
      result = El.MessageStore.session_names()

      assert result == []
    end

    test "returns unique names from store entries" do
      Application.put_env(:el, :dets_backend, DetsBackendWithEntries)

      result = El.MessageStore.session_names()

      assert result == [:dude, :kent]
    end
  end
end
