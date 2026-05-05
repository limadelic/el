defmodule El.Session.Store do
  def complete_tell_entry(state, ref, message, response) do
    new_messages = replace_tell(state.messages, ref, message, response)
    delete_tell_entry(state, message, ref)
    store_tell_entry(state, message, response)
    %{state | messages: new_messages}
  end

  defp delete_tell_entry(state, message, ref) do
    state.store_module.delete_message(
      state.name,
      {"tell", message, "", %{ref: ref}},
      message_store: state.opts[:message_store]
    )
  end

  defp store_tell_entry(state, message, response) do
    state.store_module.store_message(
      state.name,
      {"tell", message, response, %{}},
      message_store: state.opts[:message_store]
    )
  end

  def delete_ask_entry(state, message, ref) do
    state.store_module.delete_message(
      state.name,
      {"ask", message, "", %{ref: ref}},
      message_store: state.opts[:message_store]
    )
  end

  def store_ask_entry(state, entry) do
    state.store_module.store_message(state.name, entry, message_store: state.opts[:message_store])
  end

  def build_relay_entry(message, response, state) do
    {"relay", message, response, %{from: state.name}}
  end

  def store_relay_entry(state, entry) do
    state.store_module.store_message(state.name, entry, message_store: state.opts[:message_store])
    %{state | messages: state.messages ++ [entry]}
  end

  def store_ask_immediate(state, message, []) do
    ref = make_ref()
    entry = {"ask", message, "", %{ref: ref}}
    state.store_module.store_message(state.name, entry, message_store: state.opts[:message_store])
    new_state = %{state | messages: state.messages ++ [entry]}
    {ref, new_state}
  end

  def store_ask_immediate(state, _message, _routes) do
    ref = make_ref()
    {ref, state}
  end

  def store_tell_immediate(state, message, ref, []) do
    entry = {"tell", message, "", %{ref: ref}}
    state.store_module.store_message(state.name, entry, message_store: state.opts[:message_store])
    %{state | messages: state.messages ++ [entry]}
  end

  def store_tell_immediate(state, _message, _ref, _routes) do
    state
  end

  def replace_tell(messages, ref, message, response) do
    split_and_complete(messages, ref, %{type: "tell", message: message, response: response, model: nil})
  end

  def replace_ask(messages, ref, message, response, model \\ nil) do
    split_and_complete(messages, ref, %{type: "ask", message: message, response: response, model: model})
  end

  defp split_and_complete(messages, ref, %{type: type} = completion) do
    messages
    |> Enum.split_while(&match_pending_entry(&1, type, ref))
    |> complete_entry(completion)
  end

  defp match_pending_entry({type, _, "", %{ref: ref}}, type, ref), do: false
  defp match_pending_entry(_, _, _), do: true

  defp complete_entry({before, [{_, _, _, _} | rest]}, %{type: t, message: m, response: r, model: model}) do
    before ++ [{t, m, r, metadata_for(model)} | rest]
  end

  defp complete_entry({messages, []}, %{type: t, message: m, response: r, model: model}) do
    messages ++ [{t, m, r, metadata_for(model)}]
  end

  defp metadata_for(nil), do: %{}
  defp metadata_for(model), do: %{model: model}
end
