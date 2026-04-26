defmodule El.MessageStore.Spec do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      try do
        :dets.close(:message_store)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end)

    :ok
  end

  describe "delete_entry/2" do
    test "calls dets.delete_object" do
      init_test_dets()
      name = :test_entry
      entry = {"tell", "hello", "response", %{}}

      El.MessageStore.insert(name, entry)
      result = El.MessageStore.delete_entry(name, entry)

      assert result == :ok
      remaining = El.MessageStore.lookup(name)
      assert remaining == []
    end

    test "keeps other entries intact" do
      init_test_dets()
      name = :test_entries
      entry1 = {"tell", "msg1", "resp1", %{}}
      entry2 = {"tell", "msg2", "resp2", %{}}

      El.MessageStore.insert(name, entry1)
      El.MessageStore.insert(name, entry2)

      El.MessageStore.delete_entry(name, entry1)

      remaining = El.MessageStore.lookup(name)
      assert remaining == [entry2]
    end
  end

  defp init_test_dets do
    path = Path.expand("~/.el/.test_messages.dets") |> String.to_charlist()
    File.mkdir_p!(Path.expand("~/.el"))

    try do
      :dets.close(:message_store)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end

    {:ok, _} = :dets.open_file(:message_store, file: path, type: :bag)
  end
end
