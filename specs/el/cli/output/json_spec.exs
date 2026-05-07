defmodule El.CLI.Output.Json.Spec do
  use ExUnit.Case

  describe "info/1" do
    test "encodes alive session map to locked JSON shape" do
      data = %{
        name: "myagent",
        id: "abc-123",
        agent: nil,
        model: "sonnet",
        cwd: "/work",
        messages: 3,
        last_prompt: nil,
        last_response: nil,
        alive: true
      }

      assert El.CLI.Output.Json.info(data) |> Jason.decode!() == %{
        "name" => "myagent",
        "id" => "abc-123",
        "agent" => nil,
        "model" => "sonnet",
        "cwd" => "/work",
        "messages" => 3,
        "last_prompt" => nil,
        "last_response" => nil,
        "alive" => true
      }
    end
  end
end
