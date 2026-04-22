defmodule El.Features.OnOffSpec do
  use Cabbage.Feature, file: "on_off.feature"

  @el_bin "/opt/homebrew/bin/el"

  setup do
    node_file = Path.expand("~/.el/daemon_node")
    File.rm(node_file)
    on_exit(fn -> File.rm(node_file) end)
    :ok
  end

  defwhen ~r/^> (?<cmd>.+):$/, %{cmd: cmd, table: table}, _state do
    verify_with_retry(cmd, table)
  end

  defwhen ~r/^> (?<cmd>.+[^:])$/, %{cmd: cmd}, _state do
    run_el(cmd)
  end

  defp run_el(cmd) do
    rest = String.replace_prefix(cmd, "el ", "")
    args = String.split(rest)
    {output, _} = System.cmd(@el_bin, args, stderr_to_stdout: true)
    String.trim(output)
  end

  defp verify_with_retry(cmd, table, timeout \\ 5000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_verify(cmd, table, deadline)
  end

  defp do_verify(cmd, table, deadline) do
    output = run_el(cmd)

    try do
      verify_table(table, output)
    rescue
      e ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(200)
          do_verify(cmd, table, deadline)
        else
          reraise e, __STACKTRACE__
        end
    end
  end

  defp verify_table(table, output) do
    table
    |> Enum.flat_map(&Map.values/1)
    |> Enum.each(fn val ->
      val = String.trim(val)

      if String.starts_with?(val, "(") and String.ends_with?(val, ")") do
        inner = String.slice(val, 1..-2//1)

        if String.contains?(output, inner) do
          raise "Expected '#{inner}' NOT in output:\n#{output}"
        end
      else
        val
        |> String.split()
        |> Enum.each(fn word ->
          unless String.contains?(output, word) do
            raise "Expected '#{word}' in output:\n#{output}"
          end
        end)
      end
    end)
  end
end
