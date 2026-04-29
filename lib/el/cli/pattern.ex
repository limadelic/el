defmodule El.CLI.Pattern do
  alias El.CLI.Output

  def pattern?(name) do
    String.contains?(name, ["*", "?"])
  end

  def exit_by_kind(el_module, true, name), do: exit_pattern(el_module, name)
  def exit_by_kind(el_module, false, name), do: exit_single(el_module, name)

  def clear_by_kind(el_module, true, name), do: clear_pattern(el_module, name)
  def clear_by_kind(el_module, false, name), do: clear_single(el_module, name)

  defp exit_pattern(el_module, name) do
    el_module.exit_pattern(name)
    IO.puts("exited sessions matching #{name}")
  end

  defp exit_single(el_module, name) do
    result = el_module.exit(String.to_existing_atom(name))
    Output.handle_result(result, name)
  end

  defp clear_pattern(el_module, name) do
    el_module.clear_pattern(name)
    IO.puts("cleared sessions matching #{name}")
  end

  defp clear_single(el_module, name) do
    result = el_module.clear(String.to_existing_atom(name))
    Output.handle_result(result, name)
  end
end
