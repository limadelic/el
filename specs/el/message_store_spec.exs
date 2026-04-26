defmodule El.MessageStore.Spec do
  use ExUnit.Case

  setup do
    Mimic.copy(El.DetsBackend)

    on_exit(fn ->
      Application.delete_env(:el, :dets_backend)
    end)

    Application.put_env(:el, :dets_backend, El.DetsBackend)
    :ok
  end

  describe "delete_entry/2" do
    test "calls dets.delete_object with correct arguments" do
      name = :test_entry
      entry = {"tell", "hello", "response", %{}}

      Mimic.expect(El.DetsBackend, :delete_object, fn :message_store, {^name, ^entry} ->
        :ok
      end)

      result = El.MessageStore.delete_entry(name, entry)

      assert result == :ok
    end

    test "passes entry as tuple with name to backend" do
      name = :test_entries
      entry = {"tell", "msg1", "resp1", %{}}

      Mimic.expect(El.DetsBackend, :delete_object, fn :message_store, {^name, ^entry} ->
        :ok
      end)

      El.MessageStore.delete_entry(name, entry)
    end
  end
end
