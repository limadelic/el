defmodule El.CLI.Log do
  def execute_log(name, count, el_module, opts) when is_binary(name) do
    result = log_for_name(name, count, el_module, opts)
    El.CLI.Output.handle_log_result(result, name)
  end

  def execute(name, opts) do
    execute_log(name, 1, Keyword.fetch!(opts, :el_module), opts)
  end

  def execute_n(name, n, opts) do
    execute_log(name, parse_log_count(n), Keyword.fetch!(opts, :el_module), opts)
  end

  def log_for_name(name, count, el_module, opts) when is_binary(name) do
    log_by_kind(pattern?(name), name, count, el_module, opts)
  end

  def log_by_kind(true, name, count, el_module, opts) do
    el_module.log_pattern(name, count, opts)
  end

  def log_by_kind(false, name, count, el_module, opts) do
    el_module.log(String.to_atom(name), count, opts)
  end

  def parse_log_count("all"), do: :all
  def parse_log_count(n), do: String.to_integer(n)

  defp pattern?(name) do
    String.contains?(name, ["*", "?"])
  end
end
