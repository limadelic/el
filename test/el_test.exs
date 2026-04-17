defmodule ElTest do
  use ExUnit.Case
  doctest El

  test "greets the world" do
    assert El.hello() == :world
  end
end
