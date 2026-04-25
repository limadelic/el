defmodule MockSessionModule do
  def start_link(_opts), do: {:ok, :mock_pid}
  def start(_fun), do: {:ok, :task_pid}
end

if Code.ensure_loaded?(El.SessionAdapter), do: Mimic.copy(El.SessionAdapter)
if Code.ensure_loaded?(El.PortAdapter), do: Mimic.copy(El.PortAdapter)
if Code.ensure_loaded?(El.FileAdapter), do: Mimic.copy(El.FileAdapter)
Mimic.copy(Task)
Mimic.copy(MockSessionModule)

ExUnit.start()

defmodule TestClaudeCode do
  def start_link(_opts) do
    {:ok, self()}
  end

  def stream(_pid, message) do
    [text: message]
    |> Enum.into([])
  end
end

ExUnit.after_suite(fn _results ->
  System.halt(0)
end)

defmodule ModelCaptureModule do
  def start_link(opts) do
    send(self(), {:captured_opts, opts})
    {:ok, :mock_pid}
  end
end

defmodule SessionIdCaptureModule do
  def start_link(_opts) do
    {:ok, "captured-session-id"}
  end
end

defmodule FailingModule do
  def start_link(_), do: {:error, :failed}
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
