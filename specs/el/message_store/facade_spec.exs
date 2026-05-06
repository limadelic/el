defmodule El.MessageStore.Facade.Spec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "El.MessageStore.Facade.delete_session_messages/2" do
    test "delete returns :ok" do
      stub(El.MockMessageStore, :delete, fn "test-session" -> :ok end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.delete_session_messages("test-session", opts)

      assert result == :ok
    end

    test "handles delete returning error" do
      stub(El.MockMessageStore, :delete, fn "session" -> {:error, :not_found} end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.delete_session_messages("session", opts)

      assert result == {:error, :not_found}
    end

    test "passes session name through to delete unmodified" do
      stub(El.MockMessageStore, :delete, fn name -> {:deleted, name} end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.delete_session_messages("my-session", opts)

      assert result == {:deleted, "my-session"}
    end
  end

  describe "El.MessageStore.Facade.store_message/3" do
    test "store_message returns result from insert" do
      stub(El.MockMessageStore, :insert, fn "test-session", %{} -> :ok end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.store_message("test-session", %{}, opts)

      assert result == :ok
    end
  end

  describe "El.MessageStore.Facade.load_messages/2" do
    test "load_messages returns result from lookup" do
      stub(El.MockMessageStore, :lookup, fn "test-session" -> [%{data: "msg"}] end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.load_messages("test-session", opts)

      assert result == [%{data: "msg"}]
    end
  end
end
