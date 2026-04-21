defmodule El.Application.Spec do
  use ExUnit.Case

  setup do
    [
      children: El.Application.children(),
      supervisor_opts: El.Application.supervisor_opts()
    ]
  end

  test "children includes Registry", %{children: children} do
    assert {Registry, [keys: :unique, name: El.Registry]} in children
  end

  test "children includes DynamicSupervisor", %{children: children} do
    assert {DynamicSupervisor, [name: El.SessionSupervisor]} in children
  end

  test "children has exactly two entries", %{children: children} do
    assert length(children) == 2
  end

  test "supervisor opts strategy is one_for_one", %{supervisor_opts: opts} do
    assert opts[:strategy] == :one_for_one
  end

  test "supervisor opts names El.Supervisor", %{supervisor_opts: opts} do
    assert opts[:name] == El.Supervisor
  end
end
