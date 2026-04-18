defmodule El.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: El.Registry},
      {DynamicSupervisor, name: El.SessionSupervisor}
    ]

    opts = [strategy: :one_for_one, name: El.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
