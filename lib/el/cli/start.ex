defmodule El.CLI.Start do
  alias El.CLI.Start.CardBox
  alias El.CLI.Start.DaemonHealth
  alias El.CLI.Start.Options
  alias El.CLI.Start.SessionCard

  def handle_find_daemon_for_start(name, opts, el, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts ++ deps)
    DaemonHealth.ping_if_agent(name_atom, opts, deps)
    print_session_info(name, opts, deps)
  end

  def print_session_info(name, opts, deps \\ []) do
    info = session_api(deps).info(String.to_atom(name))
    rows = SessionCard.build_card_rows(name, opts, info)
    CardBox.box_frame(rows) |> Enum.each(&IO.puts/1)
  end

  defp session_api(deps) do
    Keyword.get(deps, :session_api, El.Session.Api)
  end

  def handle_find_daemon_with_rest(name, opts, rest, el, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts ++ deps)
    print_session_info(name, opts, deps)
    dispatch_rest(rest, name, opts)
  end

  def dispatch_rest([], _name, _opts) do
    :ok
  end

  def dispatch_rest(rest, name, opts) do
    El.CLI.dispatch([name | rest], opts)
  end

  def start_daemon_node_for(name, model, el, sleeper \\ El.Infra.Sleeper, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, Options.start_opts(Options.normalize_model(model)) ++ deps)
    report_daemon_up(name)
    hold_forever(sleeper)
  end

  defp report_daemon_up(name) do
    IO.puts("el: #{name} is up on #{Node.self()}")
  end

  defp hold_forever(sleeper) do
    sleeper.sleep(:infinity)
  end
end
