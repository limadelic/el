defmodule El.CLI.Daemon.Env do
  @behaviour El.CLI.Daemon.Behaviours.Env

  @impl true
  def daemon_script do
    :escript.script_name() |> to_string() |> Path.expand()
  end

  @impl true
  def daemon_node do
    dev?() |> daemon_node_for()
  end

  @impl true
  def daemon_cookie do
    dev?() |> daemon_cookie_for()
  end

  @impl true
  def dev? do
    dev_check(System.get_env("DEV"))
  end

  defp daemon_node_for(true), do: :"el_dev@127.0.0.1"
  defp daemon_node_for(false), do: :"el@127.0.0.1"

  defp daemon_cookie_for(true), do: :el_dev
  defp daemon_cookie_for(false), do: :el

  defp dev_check(nil), do: script_is_relative()
  defp dev_check(_), do: true

  defp script_is_relative do
    :escript.script_name() |> to_string() |> Path.type() |> is_relative()
  end

  defp is_relative(:relative), do: true
  defp is_relative(_), do: false
end
