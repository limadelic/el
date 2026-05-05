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

  describe "ask_tell routing through el_module" do
    test "process_tell_ask asks via el_module with enveloped message" do
      test_pid = self()
      expect(El.MockEl, :ask, fn target, msg ->
        send(test_pid, {:asked, target, msg})
        "ok"
      end)

      state = %{
        name: :sender,
        el_module: El.MockEl,
        task_module: SyncTask,
        alive_fn: fn _ -> true end
      }

      Router.process_tell_ask(state, :target, "question")

      assert_receive {:asked, :target, "[from sender] question"}
    end

    test "process_ask_tell tells via el_module with enveloped message" do
      test_pid = self()
      expect(El.MockEl, :tell, fn target, msg ->
        send(test_pid, {:told, target, msg})
        :ok
      end)

      state = %{
        name: :sender,
        el_module: El.MockEl,
        alive_fn: fn _ -> true end
      }

      Router.process_ask_tell(state, :target, "question")

      assert_receive {:told, :target, "[from sender] question"}
    end
  end

  describe "tell_response routing through session_api" do
    test "process_tell_response tells via session_api with enveloped payload" do
      test_pid = self()
      expect(El.MockSessionApi, :tell, fn target, msg ->
        send(test_pid, {:told_response, target, msg})
        :ok
      end)
      stub(El.MockSessionApi, :cast_store_relay, fn _name, _payload, _response ->
        :ok
      end)

      state = %{
        name: :sender,
        session_api: El.MockSessionApi,
        alive_fn: fn _ -> true end
      }

      Router.process_tell_response(state, "response", [{:target, "payload"}])

      assert_receive {:told_response, :target, "[from sender] payload"}
    end
  end
end
