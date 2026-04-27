defmodule El.ClaudeCode.Spec do
  use ExUnit.Case

  setup do
    on_exit(fn -> Application.delete_env(:claude_code, :cli_path) end)
    :ok
  end

  describe "start_link/1" do
    test "passes session_id from options" do
      defmodule SessionIdTest do
        def start_link(opts) do
          assert opts[:session_id] == "test-session-id"
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(session_id: "test-session-id", session_module: SessionIdTest)
    end

    test "passes adapter configuration tuple" do
      defmodule AdapterTest do
        def start_link(opts) do
          assert {ClaudeCode.Adapter.Port, _} = opts[:adapter]
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(session_module: AdapterTest)
    end

    test "passes dangerously_skip_permissions flag as true" do
      defmodule PermissionsTest do
        def start_link(opts) do
          assert opts[:dangerously_skip_permissions] == true
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(session_module: PermissionsTest)
    end

    test "includes model when provided" do
      defmodule ModelIncludedTest do
        def start_link(opts) do
          assert opts[:model] == "claude-3-5-haiku"
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(
        model: "claude-3-5-haiku",
        session_module: ModelIncludedTest
      )
    end

    test "omits model when not provided" do
      defmodule ModelOmittedTest do
        def start_link(opts) do
          refute Keyword.has_key?(opts, :model)
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(session_module: ModelOmittedTest)
    end

    test "passes configured cli_path from application environment" do
      Application.put_env(:claude_code, :cli_path, "/custom/path")

      defmodule CliPathConfiguredTest do
        def start_link(opts) do
          {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
          assert adapter_opts[:cli_path] == "/custom/path"
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(session_module: CliPathConfiguredTest)
    end

    test "defaults cli_path to :global when not configured" do
      Application.delete_env(:claude_code, :cli_path)

      defmodule CliPathDefaultTest do
        def start_link(opts) do
          {ClaudeCode.Adapter.Port, adapter_opts} = opts[:adapter]
          assert adapter_opts[:cli_path] == :global
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(session_module: CliPathDefaultTest)
    end

    test "passes resume option when provided" do
      defmodule ResumeIncludedTest do
        def start_link(opts) do
          assert opts[:resume] == "abc-123-def"
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(
        resume: "abc-123-def",
        session_module: ResumeIncludedTest
      )
    end

    test "omits resume option when not provided" do
      defmodule ResumeOmittedTest do
        def start_link(opts) do
          refute Keyword.has_key?(opts, :resume)
          {:ok, self()}
        end
      end

      El.ClaudeCode.start_link(session_module: ResumeOmittedTest)
    end
  end

  describe "stream/2" do
    test "delegates to session module" do
      result = El.ClaudeCode.stream(:pid, "prompt")
      assert result != nil
    end
  end
end
