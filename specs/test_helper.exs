defmodule MockSessionModule do
  def start_link(_opts), do: {:ok, :mock_pid}
  def start(_fun), do: {:ok, :task_pid}
end

defmodule SyncTask do
  def start(fun), do: fun.()
end

:application.load(:el)

el_ebin_dir = "#{File.cwd!()}/_build/test/lib/el/ebin"
el_modules = case File.ls(el_ebin_dir) do
  {:ok, files} -> files
  :error -> []
end
|> Enum.filter(&String.ends_with?(&1, ".beam"))
|> Enum.map(&String.replace(&1, ".beam", ""))
|> Enum.map(&String.to_atom/1)

extra_dirs = [
  "#{File.cwd!()}/_build/test/lib/claude_code/ebin",
  "#{File.cwd!()}/_build/test/lib/mox/ebin",
  "#{File.cwd!()}/_build/test/lib/jason/ebin"
]

extra_modules = extra_dirs
  |> Enum.flat_map(fn dir ->
    case File.ls(dir) do
      {:ok, files} -> files
      :error -> []
    end
  end)
  |> Enum.filter(&String.ends_with?(&1, ".beam"))
  |> Enum.map(&String.replace(&1, ".beam", ""))
  |> Enum.map(&String.to_atom/1)

(el_modules ++ extra_modules)
|> Enum.uniq()
|> Enum.each(&Code.ensure_loaded!/1)

Mox.defmock(El.MockRegistry, for: El.Behaviours.Registry)
Mox.defmock(El.MockSupervisor, for: El.Behaviours.Supervisor)
Mox.defmock(El.MockSession, for: El.Behaviours.Session)
Mox.defmock(El.MockApp, for: El.Behaviours.App)
Mox.defmock(El.MockMonitor, for: El.Behaviours.Monitor)
Mox.defmock(El.MockEl, for: El.Behaviours.El)
Mox.defmock(El.MockFileSystem, for: El.Behaviours.FileSystem)
Mox.stub(El.MockFileSystem, :cwd, fn -> "/tmp/test" end)
Mox.stub(El.MockFileSystem, :mkdir_p!, fn _path -> :ok end)

defmodule ClaudeCode.SessionStub do
  def stream(_pid, _prompt) do
    Stream.resource(fn -> nil end, fn _ -> :halt end, fn _ -> :ok end)
  end
end

defmodule El.DetsBackendStub do
  def delete_object(_table, _key), do: :ok
  def foldl(_table, acc, _fun), do: acc
  def insert(_table, _key_entry), do: :ok
  def lookup(_table, _key), do: []
  def delete(_table, _key), do: :ok
  def open_file(_table, _opts), do: {:ok, :stub_ref}
  def close(_table), do: :ok
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

defmodule AgentDetectorStub do
  def detect_agent("kent"), do: "kent"
  def detect_agent(_), do: nil
end

defmodule NilAgentDetectorStub do
  def detect_agent(_), do: nil
end

defmodule IdentityAgentDetectorStub do
  def detect_agent(name), do: name
end

Mox.defmock(El.MockSessionApi, for: El.Behaviours.Session)
Mox.defmock(El.MockClaudeCode, for: El.Platform.Behaviours.Code)
Mox.defmock(El.MockClaudeCodeSession, for: El.Platform.Behaviours.CodeSession)
Mox.defmock(El.MockStoreModule, for: El.MessageStore.Behaviours.Store)
Mox.defmock(El.MockSessionMeta, for: El.SessionMeta)
Mox.defmock(El.MockSessionAsk, for: El.Behaviours.SessionAsk)
Mox.defmock(El.MockDets, for: El.MessageStore.Behaviours.Dets)
Mox.defmock(El.MockPort, for: El.Behaviours.Port)
Mox.defmock(El.MockSleeper, for: El.Behaviours.Sleeper)
Mox.defmock(El.MockNodeConnector, for: El.Behaviours.NodeConnector)
Mox.defmock(El.MockNetKernel, for: El.Behaviours.NetKernel)
Mox.defmock(El.MockSessionClaude, for: El.Behaviours.SessionClaude)
Mox.defmock(El.MockSystem, for: El.Behaviours.System)
Mox.defmock(El.MockGroupLeader, for: El.Behaviours.GroupLeader)
Mox.defmock(El.MockMessageStore, for: El.MessageStore.Behaviours.MessageStore)
Mox.defmock(El.MockMessageStoreInit, for: El.MessageStore.Behaviours.Init)
Mox.defmock(El.MockSessionRestorer, for: El.Behaviours.SessionRestorer)
Mox.defmock(El.MockAgentDetector, for: El.Agent.Behaviours.Detector)
Mox.defmock(El.MockAgentMetadata, for: El.Agent.Behaviours.Metadata)
Mox.defmock(El.MockEnv, for: El.Behaviours.Env)
Mox.defmock(El.MockCCParser, for: El.Platform.Behaviours.Parser)
Mox.defmock(El.MockJSONDecoder, for: El.Behaviours.JSONDecoder)
Mox.defmock(El.MockCardBox, for: El.Behaviours.CardBox)
Mox.defmock(El.MockTextFormatter, for: El.Behaviours.TextFormatter)
Mox.defmock(El.MockParser, for: El.ClaudePort.Behaviours.Parser)
Mox.defmock(El.MockParserEventSchema, for: El.ClaudePort.Behaviours.Parser.EventSchema)
Mox.defmock(El.MockParserResult, for: El.ClaudePort.Behaviours.Parser.Result)
Mox.defmock(El.MockClaudePortConnection, for: El.ClaudePort.Behaviours.Connection)
Mox.defmock(El.MockSessionBootstrap, for: El.Behaviours.SessionBootstrap)
Mox.defmock(El.MockClaudePortCliResolver, for: El.ClaudePort.Behaviours.CliResolver)
Mox.defmock(El.MockClaudePortPortSpawn, for: El.ClaudePort.Behaviours.PortSpawn)
Mox.defmock(El.MockClaudePortCloser, for: El.ClaudePort.Behaviours.Closer)

Mox.stub(El.MockNodeConnector, :connect, fn _ -> false end)
Mox.stub(El.MockNodeConnector, :set_cookie, fn _ -> true end)
Mox.stub(El.MockGroupLeader, :open_null_device, fn -> self() end)
Mox.stub(El.MockGroupLeader, :close, fn _ -> :ok end)
Mox.stub(El.MockGroupLeader, :get, fn -> self() end)
Mox.stub(El.MockGroupLeader, :set, fn _, _ -> true end)

defmodule MockClaudeCodeSession do
  def stream(_pid, _message) do
    [
      %ClaudeCode.Message.SystemMessage.Init{
        model: "test-model",
        type: "system",
        subtype: "init",
        session_id: "test-session-id"
      },
      %ClaudeCode.Message.ResultMessage{
        result: "test result",
        type: "result",
        subtype: "result",
        is_error: false,
        duration_ms: 0,
        duration_api_ms: 0,
        num_turns: 0,
        session_id: "test-session-id",
        total_cost_usd: 0.0,
        usage: %{}
      }
    ]
    |> Stream.concat([])
  end

  def start_link(_opts) do
    {:ok, :mock_pid}
  end
end

Application.put_env(:el, :session_meta, El.MockSessionMeta)
Application.put_env(:el, :file_system, El.MockFileSystem)
Application.put_env(:el, :parser, El.MockParser)

ExUnit.start(timeout: 20)

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

defmodule TestClaudePortStub do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:ask, _message}, _from, state) do
    {:reply, {"test result", "test-model", "test-session-id"}, state}
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
