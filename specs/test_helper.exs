ExUnit.start()

defmodule TestCLI do
  def run(args) do
    case System.cmd("./el", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, code, output}
    end
  end

  def run!(args) do
    case run(args) do
      {:ok, output} -> output
      {:error, code, output} -> raise "CLI failed with code #{code}: #{output}"
    end
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
