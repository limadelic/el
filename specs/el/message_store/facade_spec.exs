defmodule El.MessageStore.Facade.Spec do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  describe "El.MessageStore.Facade.delete_session_messages/2" do
    test "calls message_store.delete with name" do
      expect(El.MockMessageStore, :delete, fn "session-name" -> :ok end)
      opts = [message_store: El.MockMessageStore]

      El.MessageStore.Facade.delete_session_messages("session-name", opts)

      verify!()
    end

    test "calls message_store.delete when opts provided" do
      expect(El.MockMessageStore, :delete, fn "test-session" -> :ok end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.delete_session_messages("test-session", opts)

      assert result == :ok
    end

    test "handles delete returning error" do
      expect(El.MockMessageStore, :delete, fn "session" -> {:error, :not_found} end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.delete_session_messages("session", opts)

      assert result == {:error, :not_found}
    end

    test "raises when message_store missing from opts" do
      assert_raise KeyError, fn ->
        El.MessageStore.Facade.delete_session_messages("session", [])
      end
    end

    test "passes session name through to delete unmodified" do
      expect(El.MockMessageStore, :delete, fn name -> {:deleted, name} end)
      opts = [message_store: El.MockMessageStore]

      result = El.MessageStore.Facade.delete_session_messages("my-session", opts)

      assert result == {:deleted, "my-session"}
    end
  end
end
