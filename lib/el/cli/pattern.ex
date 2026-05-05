defmodule El.CLI.Pattern do
  alias El.CLI.Output

  def pattern?(name) do
    String.contains?(name, ["*", "?"])
  end

  def exit_by_kind(el_module, true, name, opts), do: exit_pattern(el_module, name, opts)
  def exit_by_kind(el_module, false, name, opts), do: exit_single(el_module, name, opts)

  def clear_by_kind(el_module, true, name, opts), do: clear_pattern(el_module, name, opts)
  def clear_by_kind(el_module, false, name, opts), do: clear_single(el_module, name, opts)

  defp exit_pattern(el_module, name, opts) do
    el_module.exit_pattern(name, opts)
    IO.puts("exited sessions matching #{name}")
  end

  defp exit_single(el_module, name, opts) do
    result = el_module.exit(String.to_existing_atom(name), opts)
    Output.handle_result(result, name)
  end

  defp clear_pattern(el_module, name, opts) do
    el_module.clear_pattern(name, opts)
    IO.puts("cleared sessions matching #{name}")
  end

  defp clear_single(el_module, name, opts) do
    result = el_module.clear(String.to_existing_atom(name), opts)
    Output.handle_result(result, name)
  end
end
