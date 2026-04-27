defmodule El.CLI.Start do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model("") do
    nil
  end

  def normalize_model(model) do
    model
  end

  def handle_find_daemon_for_start(name, opts, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    IO.puts("el: #{name} is up")
  end

  def handle_find_daemon_with_rest(name, opts, rest, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    dispatch_rest(rest, name)
  end

  def dispatch_rest([], _name) do
    :ok
  end

  def dispatch_rest(rest, name) do
    El.CLI.dispatch([name | rest])
  end

  def start_daemon_node_for(name, model, el) do
    name_atom = String.to_atom(name)
    opts = start_opts(normalize_model(model))
    el.start(name_atom, opts)
    IO.puts("el: #{name} is up on #{Node.self()}")
    Process.sleep(:infinity)
  end
end
