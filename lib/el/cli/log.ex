defmodule El.CLI.Log do
  def execute_log(name, count, el_module) when is_binary(name) do
    result = log_for_name(name, count, el_module)
    El.CLI.Output.handle_log_result(result, name)
  end

  def log_for_name(name, count, el_module) when is_binary(name) do
    log_by_kind(pattern?(name), name, count, el_module)
  end

  def log_by_kind(true, name, count, el_module) do
    el_module.log_pattern(name, count)
  end

  def log_by_kind(false, name, count, el_module) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    el_module.log(String.to_atom(name), count)
  end

  def parse_log_count("all"), do: :all
  def parse_log_count(n), do: String.to_integer(n)

  defp pattern?(name) do
    String.contains?(name, ["*", "?"])
  end
end
