defmodule El.CLI.Msg do
  alias El.CLI.Output

  def dispatch(name, words, el_module, deps) do
    name_atom = String.to_atom(name)
    result = el_module.ask(name_atom, Enum.join(words, " "), deps)
    Output.handle_result(result, sender_name(el_module, name_atom, name, deps))
  end

  defp sender_name(el_module, name_atom, fallback, opts) do
    pick_name(agent_lookup(el_module, name_atom, opts), fallback)
  end

  defp pick_name(nil, fallback), do: fallback
  defp pick_name(agent, _fallback), do: agent

  defp agent_lookup(el_module, name_atom, opts) do
    el_module.agent(name_atom, opts)
  catch
    _ -> nil
  end
end
