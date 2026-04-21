Application.ensure_all_started(:mimic)

Mimic.copy(El.SessionAdapter)
Mimic.copy(El.PortAdapter)
Mimic.copy(El.FileAdapter)
Mimic.copy(Task)

ExUnit.start()

defmodule MockSessionModule do
  def start_link(_), do: {:ok, :mock_pid}
  def start(_fun), do: {:ok, :task_pid}
end

defmodule MockTaskModule do
  def start(_fun), do: {:ok, :task_pid}
end

defmodule TestCLI do
  def run(args) do
    {output, code} = System.cmd("./el", args, stderr_to_stdout: true)
    handle_cmd_result(code, output)
  end

  defp handle_cmd_result(0, output), do: {:ok, output}
  defp handle_cmd_result(code, output), do: {:error, code, output}

  def run!(args) do
    extract_output_or_raise(run(args))
  end

  defp extract_output_or_raise({:ok, output}) do
    output
  end

  defp extract_output_or_raise({:error, code, output}) do
    raise "CLI failed with code #{code}: #{output}"
  end

  def parse_session_list(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(String.length(&1) > 0))
  end

  def allow_cli_error({:ok, output}), do: {:ok, output}
  def allow_cli_error({:error, _, output}), do: {:ok, output}
end
