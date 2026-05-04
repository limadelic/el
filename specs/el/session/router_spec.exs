defmodule El.Session.RouterSpec do
  use ExUnit.Case
  import Mox
  alias El.Session.Router

  setup_all do
    Code.ensure_loaded!(El.Session.Router)
    :ok
  end

  setup :verify_on_exit!

  test "filter_self_routes drops routes targeting state.name" do
    state = %{name: :test_session}
    routes = [{:test_session, "msg"}, {:other, "msg"}]
    assert Router.filter_self_routes(routes, state) == [{:other, "msg"}]
  end

  describe "cast_store_relay routing" do
    test "tell_route_target relays to target with empty response" do
      test_pid = self()
      expect(El.MockSessionApi, :cast_store_relay, 2, fn name, payload, response ->
        send(test_pid, {:relayed, name, payload, response})
        :ok
      end)

      state = %{
        name: :sender,
        session_api: El.MockSessionApi,
        alive_fn: fn _ -> true end
      }

      Router.route_all_tells(state, "msg", [{:target, "payload"}])

      assert_receive {:relayed, :target, "[from sender] payload", ""}
    end

    test "tell_route_target relays to self with target tag" do
      test_pid = self()
      expect(El.MockSessionApi, :cast_store_relay, 2, fn name, payload, response ->
        send(test_pid, {:relayed, name, payload, response})
        :ok
      end)

      state = %{
        name: :sender,
        session_api: El.MockSessionApi,
        alive_fn: fn _ -> true end
      }

      Router.route_all_tells(state, "msg", [{:target, "payload"}])

      assert_receive {:relayed, :sender, "msg", "-> target"}
    end
  end
end
