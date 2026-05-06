defmodule El.Deps.Spec do
  use ExUnit.Case

  describe "El.Deps.production/0" do
    test "returns map with init_module key defaulting to El.MessageStore.Init" do
      result = El.Deps.production()

      assert Keyword.get(result, :init_module) == El.MessageStore.Init
    end

    test "returns map with restorer_module key defaulting to El.SessionRestorer" do
      result = El.Deps.production()

      assert Keyword.get(result, :restorer_module) == El.SessionRestorer
    end

    test "returns map with connection_module key defaulting to El.ClaudePort.Connection" do
      result = El.Deps.production()

      assert Keyword.get(result, :connection_module) == El.ClaudePort.Connection
    end

    test "core_modules defaults bootstrap_module to El.Session.Bootstrap" do
      result = El.Deps.production()

      assert Keyword.get(result, :bootstrap_module) == El.Session.Bootstrap
    end

    test "core_modules defaults cli_resolver_module to El.ClaudePort.Connection.CliResolver" do
      result = El.Deps.production()

      assert Keyword.get(result, :cli_resolver_module) == El.ClaudePort.Connection.CliResolver
    end
  end

  describe "El.Deps.monitor/1" do
    test "returns monitor value from opts" do
      monitor = El.Infra.Monitor
      opts = [monitor: monitor]

      assert El.Deps.monitor(opts) == monitor
    end

    test "raises KeyError when monitor key missing from opts" do
      error = catch_error(El.Deps.monitor([]))

      assert is_struct(error, KeyError)
      assert error.key == :monitor
    end
  end

  describe "El.Deps.supervisor/1" do
    test "returns supervisor value from opts" do
      supervisor = DynamicSupervisor
      opts = [supervisor: supervisor]

      assert El.Deps.supervisor(opts) == supervisor
    end

    test "raises KeyError when supervisor key missing from opts" do
      error = catch_error(El.Deps.supervisor([]))

      assert is_struct(error, KeyError)
      assert error.key == :supervisor
    end
  end

  describe "El.Deps.registry/1" do
    test "returns registry value from opts" do
      registry = Registry
      opts = [registry: registry]

      assert El.Deps.registry(opts) == registry
    end

    test "raises KeyError when registry key missing from opts" do
      error = catch_error(El.Deps.registry([]))

      assert is_struct(error, KeyError)
      assert error.key == :registry
    end
  end
end
