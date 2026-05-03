defmodule El.Session.RouterSpec do
  use ExUnit.Case
  alias El.Session.Router

  setup_all do
    Code.ensure_loaded!(El.Session.Router)
    :ok
  end

  test "filter_self_routes drops routes targeting state.name" do
    state = %{name: :test_session}
    routes = [{:test_session, "msg"}, {:other, "msg"}]
    assert Router.filter_self_routes(routes, state) == [{:other, "msg"}]
  end
end
