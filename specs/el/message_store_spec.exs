defmodule DetsBackendWithEntries do
  def delete_object(_table, _key), do: :ok

  def foldl(_table, acc, fun) do
    acc = fun.({:dude, {"ask", "hi", "hello", %{}}}, acc)
    fun.({:kent, {"tell", "yo", "", %{}}}, acc)
  end
end

defmodule El.MessageStore.Spec do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "delete_entry/3" do
    test "calls dets.delete_object with correct arguments" do
      name = :test_entry
      entry = {"tell", "hello", "response", %{}}

      expect(El.MockDets, :delete_object, fn :message_store, {^name, ^entry} -> :ok end)

      assert El.MessageStore.delete_entry(name, entry, [dets_backend: El.MockDets]) == :ok
    end
  end

  describe "session_names/1" do
    test "returns empty list when no sessions" do
      result = El.MessageStore.session_names([dets_backend: El.DetsBackendStub])

      assert result == []
    end

    test "returns unique names from store entries" do
      result = El.MessageStore.session_names([dets_backend: DetsBackendWithEntries])
      sorted_result = Enum.sort(result)

      assert sorted_result == [:dude, :kent]
    end
  end
end
