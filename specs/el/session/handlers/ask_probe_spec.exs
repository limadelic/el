defmodule El.Session.Handlers.Ask.ProbeSpec do
  use ExUnit.Case
  import Mox
  setup :verify_on_exit!

  setup do
    Mox.stub(El.MockSessionMeta, :insert, fn _, _, _, _ -> :ok end)
    Mox.stub(El.MockFileSystem, :cwd!, fn -> "/test/dir" end)

    state = %{
      name: :test_session,
      claude_pid: nil,
      session_id: nil,
      cwd: "/test/dir",
      messages: [],
      pending_calls: [],
      claude_module: MockSessionModule,
      task_module: MockSessionModule,
      alive_fn: fn _ -> false end,
      registry_module: MockSessionModule,
      store_module: MockProbeStore,
      session_meta: El.MockSessionMeta,
      ask_module: El.Session.Handlers.Ask,
      session_api: El.MockSessionApi,
      el_module: El.MockEl,
      opts: [],
      claude_opts: []
    }

    {:ok, state: state}
  end

  describe "prepare_probe" do
    test "does not store message to messages list", %{state: state} do
      from = {self(), make_ref()}
      {_ref, state_after} = El.Session.Handlers.Ask.prepare_probe(state, from, "who are you?")
      assert state_after.messages == []
    end

    test "still adds from to pending_calls", %{state: state} do
      from = {self(), make_ref()}
      {_ref, state_after} = El.Session.Handlers.Ask.prepare_probe(state, from, "who are you?")
      assert from in state_after.pending_calls
    end

    test "returns a ref for GenServer reply", %{state: state} do
      from = {self(), make_ref()}
      {ref, _state_after} = El.Session.Handlers.Ask.prepare_probe(state, from, "who are you?")
      assert is_reference(ref)
    end
  end

  describe "prepare_ask (normal ask)" do
    test "stores message to messages list", %{state: state} do
      from = {self(), make_ref()}
      {_ref, state_after} = El.Session.Handlers.Ask.prepare_ask(state, from, "who are you?")
      assert length(state_after.messages) == 1
      assert [{"ask", "who are you?", "", %{ref: _ref}}] = state_after.messages
    end

    test "adds from to pending_calls", %{state: state} do
      from = {self(), make_ref()}
      {_ref, state_after} = El.Session.Handlers.Ask.prepare_ask(state, from, "who are you?")
      assert from in state_after.pending_calls
    end
  end

  describe "integration: probe flow with session_id capture" do
    test "probe message does not appear in final messages", %{state: state} do
      from = {self(), make_ref()}
      {ref, state_after_prepare} = El.Session.Handlers.Ask.prepare_probe(state, from, "who are you?")

      assert state_after_prepare.messages == []

      ask = %{from: from, ref: ref, message: "who are you?", response: "I am Claude", model: nil}
      state_after_finalize = El.Session.Handlers.Ask.finalize_probe(state_after_prepare, ask)

      assert state_after_finalize.messages == []
    end

    test "normal ask stores message even if it is 'who are you?'", %{state: state} do
      from = {self(), make_ref()}
      {ref, state_after_prepare} = El.Session.Handlers.Ask.prepare_ask(state, from, "who are you?")

      assert length(state_after_prepare.messages) == 1

      ask = %{from: from, ref: ref, message: "who are you?", response: "I am Claude", model: "claude-3-opus"}
      state_after_finalize = El.Session.Handlers.Ask.finalize_ask(state_after_prepare, ask)

      assert length(state_after_finalize.messages) == 1
      assert [{"ask", "who are you?", "I am Claude", %{model: "claude-3-opus"}}] = state_after_finalize.messages
    end
  end
end

defmodule MockProbeStore do
  def store_message(_, _, _), do: :ok
  def store_message(_, _), do: :ok
  def load_messages(_, _opts \\ []), do: []
  def delete_message(_, _, _), do: :ok
  def delete_message(_, _), do: :ok
  def delete_session_messages(_), do: :ok
  def delete_ask_entry(_state, _message, _ref), do: :ok
  def store_ask_entry(_, _), do: :ok
  def replace_ask(messages, ref, message, response, model) do
    messages
    |> Enum.split_while(&match_pending(&1, ref))
    |> complete(message, response, model)
  end

  defp match_pending({_, _, "", %{ref: ref}}, ref), do: false
  defp match_pending(_, _), do: true

  defp complete({before, [{_, _, _, _} | rest]}, message, response, model) do
    before ++ [{"ask", message, response, metadata(model)} | rest]
  end

  defp complete({messages, []}, message, response, model) do
    messages ++ [{"ask", message, response, metadata(model)}]
  end

  defp metadata(nil), do: %{}
  defp metadata(model), do: %{model: model}
end
