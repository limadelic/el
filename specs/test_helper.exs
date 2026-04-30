defmodule MockSessionModule do
  def start_link(_opts), do: {:ok, :mock_pid}
  def start(_fun), do: {:ok, :task_pid}
end

Mox.defmock(El.MockRegistry, for: El.Behaviours.Registry)
Mox.defmock(El.MockSupervisor, for: El.Behaviours.Supervisor)
Mox.defmock(El.MockSession, for: El.Behaviours.Session)
Mox.defmock(El.MockApp, for: El.Behaviours.App)
Mox.defmock(El.MockMonitor, for: El.Behaviours.Monitor)
Mox.defmock(El.MockEl, for: El.Behaviours.El)
Mox.defmock(El.MockFileSystem, for: El.Behaviours.FileSystem)

defmodule ClaudeCode.SessionStub do
  def stream(_pid, _prompt) do
    Stream.resource(fn -> nil end, fn _ -> :halt end, fn _ -> :ok end)
  end
end

defmodule El.DetsBackendStub do
  def delete_object(_table, _key), do: :ok
  def foldl(_table, acc, _fun), do: acc
end

defmodule El.MessageStoreStub do
  def insert(_name, _entry), do: :ok
  def lookup(_name), do: []
  def delete(_name), do: :ok
  def close, do: :ok
end

defmodule AgentMetadataStub do
  def model_for("kent"), do: "opus"
  def model_for(_), do: nil
end

defmodule NilAgentMetadataStub do
  def model_for(_), do: nil
end

Mox.defmock(El.MockSessionApi, for: El.Behaviours.Session)

Application.put_env(:el, :registry, El.MockRegistry)
Application.put_env(:el, :supervisor, El.MockSupervisor)
Application.put_env(:el, :session, El.MockSession)
Application.put_env(:el, :session_api, El.MockSessionApi)
Application.put_env(:el, :app, El.MockApp)
Application.put_env(:el, :monitor, El.MockMonitor)
Application.put_env(:el, :el_module, El.MockEl)

ExUnit.start(timeout: 10)

defmodule TestClaudeCode do
  def start_link(_opts) do
    {:ok, self()}
  end

  def stream(_pid, message) do
    [text: message]
    |> Enum.into([])
  end
end


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
