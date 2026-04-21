defmodule El.Application.Spec do
  use ExUnit.Case

  describe "children/0" do
    test "includes Registry with unique keys" do
      assert {Registry, [keys: :unique, name: El.Registry]} in El.Application.children()
    end

    test "includes DynamicSupervisor for sessions" do
      assert {DynamicSupervisor, [name: El.SessionSupervisor]} in El.Application.children()
    end

    test "has exactly two children" do
      assert length(El.Application.children()) == 2
    end
  end

  describe "supervisor_opts/0" do
    test "sets strategy to one_for_one" do
      assert El.Application.supervisor_opts()[:strategy] == :one_for_one
    end

    test "names the supervisor El.Supervisor" do
      assert El.Application.supervisor_opts()[:name] == El.Supervisor
    end
  end
end
