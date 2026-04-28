defmodule El.CLI.Output do
  @usage_cmds [
    {"el VERSION", ""},
    {"el -v", "version"},
    {"el ls", "list sessions"},
    {"el <name> [-m <model>]", "start or status"},
    {"el <name> <msg>", "send a msg"},
    {"el <name|glob> log [n|all]", "view log (default: last 1)"},
    {"el <name|glob> clear", "clear log"},
    {"el <name|glob> exit", "exit session"},
    {"el exit", "exit all sessions"},
    {"el restart", "restart daemon"}
  ]

  defp version do
    Application.spec(:el, :vsn) |> format_version()
  end

  def format_version(vsn) when is_list(vsn), do: "v" <> List.to_string(vsn)
  def format_version(_), do: "v0.1.0"

  def usage_message do
    cmds = @usage_cmds |> List.replace_at(0, {"el #{version()}", ""})
    pad = max_cmd_length(cmds)
    Enum.map_join(cmds, "\n", &format_line(&1, pad))
  end

  def show_sessions([]) do
  end

  def show_sessions(names) do
    Enum.each(names, &IO.puts/1)
  end

  def handle_not_found(name) do
    IO.puts("No sessions running. Start one: el #{name}")
  end

  def handle_result(:not_found, name) do
    handle_not_found(name)
  end

  def handle_result(response, _name) do
    IO.puts(response)
  end

  def handle_log_result(:not_found, name) do
    handle_not_found(name)
  end

  def handle_log_result(log, _name) do
    Enum.each(log, &log_line/1)
  end

  defp log_line({_type, message, "", _metadata}) do
    IO.puts("> #{message}")
  end

  defp log_line({_type, message, response, _metadata}) do
    IO.puts("> #{message}")
    IO.puts("> #{response}")
  end

  defp max_cmd_length(cmds) do
    cmds |> Enum.map(fn {cmd, _} -> String.length(cmd) end) |> Enum.max()
  end

  defp format_line({cmd, ""}, _pad), do: cmd

  defp format_line({cmd, desc}, pad) do
    String.pad_trailing(cmd, pad) <> "  " <> desc
  end
end
