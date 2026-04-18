defmodule ElTest do
  use ExUnit.Case

  test "el module loads" do
    assert Code.ensure_loaded?(El)
  end
end
