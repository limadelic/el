defmodule El.CLI.Daemon.Env do
  @behaviour El.CLI.Daemon.Behaviours.Env

  @impl true
  def daemon_script do
    :escript.script_name() |> to_string() |> Path.expand()
  end

  @impl true
  def daemon_node do
    dev?() |> daemon_node_for(host())
  end

  @impl true
  def daemon_cookie do
    dev?() |> daemon_cookie_for()
  end

  @impl true
  def dev? do
    dev_check(env_module().get("DEV"))
  end

  def host, do: env_module().get("EL_HOST") || "127.0.0.1"
  def remote_node, do: env_module().get("EL_NODE")

  def naming_mode(h), do: (if String.contains?(h, "."), do: :longnames, else: :shortnames)

  defp daemon_node_for(true, h), do: :"el_dev@#{h}"
  defp daemon_node_for(false, h), do: :"el@#{h}"

  defp daemon_cookie_for(true), do: :el_dev
  defp daemon_cookie_for(false), do: :el

  defp dev_check(nil), do: script_is_relative()
  defp dev_check(_), do: true

  defp script_is_relative do
    :escript.script_name() |> to_string() |> Path.type() |> is_relative()
  end

  defp is_relative(:relative), do: true
  defp is_relative(_), do: false

  defp env_module, do: Application.get_env(:el, :env_module, El.Infra.Env)
end
