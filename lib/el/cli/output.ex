defmodule El.CLI.Output do
  @usage_template """
  el {{vsn}}

  el -v                                 version
  el ls                                 list names
  el <name> [-json]                     info
  el <name> log [n|all] [-json]         view log (default: last 1)

  el <name> start [args]                start session
    args:
      -m <model>                        model
      -a <agent>                        agent

  el <name> <msg>                       send a msg

  el <name|glob> <cmd>                  apply command to one or many
  el <cmd>                              apply command to all
    cmds:
      clear                             start new session
      exit                              exit session
      restart                           restart session
  """

  defp version do
    Application.spec(:el, :vsn) |> format_version()
  end

  def format_version(vsn) when is_list(vsn), do: "v" <> List.to_string(vsn)
  def format_version(_), do: "v0.1.0"

  def usage_message do
    @usage_template |> String.replace("{{vsn}}", version()) |> String.trim_trailing()
  end

  def show_sessions([]), do: nil
  def show_sessions(names), do: Enum.each(names, &IO.puts/1)

  def handle_not_found(name) do
    IO.puts("No sessions running. Start one: el #{name}")
  end

  def handle_result(:not_found, name), do: handle_not_found(name)

  def handle_result(response, _name) do
    IO.puts("")
    IO.puts(response)
    IO.puts("")
  end

  def handle_log_result(:not_found, name), do: handle_not_found(name)

  def handle_log_result(log, _name) do
    log |> Enum.intersperse(:blank_line) |> Enum.each(&print_log_item/1)
  end

  defp print_log_item(:blank_line), do: IO.puts("")

  defp print_log_item({_type, message, "", _metadata}) do
    IO.puts("> #{message}")
  end

  defp print_log_item({_type, message, response, _metadata}) do
    IO.puts("> #{message}")
    IO.puts("> #{response}")
  end
end
