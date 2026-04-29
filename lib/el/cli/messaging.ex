defmodule El.CLI.Messaging do
  alias El.CLI.Output

  def handle_tell_ask(name_atom, target_atom, msg, name, el_module) do
    result = el_module.tell_ask(name_atom, target_atom, msg)
    Output.handle_result(result, name)
  end

  def handle_ask_tell(name_atom, target_atom, msg, name, el_module) do
    result = el_module.ask_tell(name_atom, target_atom, msg)
    Output.handle_result(result, name)
  end

  def handle_msg(name_atom, msg, name, el_module) do
    result = el_module.ask(name_atom, msg)
    agent_name = agent_safe(el_module, name_atom, name)
    Output.handle_result(result, resolve_name(agent_name, name))
  end

  defp agent_safe(el_module, name_atom, _fallback) do
    el_module.agent(name_atom)
  catch
    _ -> nil
  end

  defp resolve_name(nil, fallback), do: fallback
  defp resolve_name(agent, _fallback), do: agent

  def execute_tell_ask(name, target, words, el_module) do
    target_atom = String.to_atom(target)
    name_atom = String.to_atom(name)
    handle_tell_ask(name_atom, target_atom, Enum.join(words, " "), name, el_module)
  end

  def execute_ask_tell(name, target, words, el_module) do
    target_atom = String.to_atom(target)
    name_atom = String.to_atom(name)
    handle_ask_tell(name_atom, target_atom, Enum.join(words, " "), name, el_module)
  end

  def execute_msg(name, words, el_module) do
    name_atom = String.to_atom(name)
    handle_msg(name_atom, Enum.join(words, " "), name, el_module)
  end
end
