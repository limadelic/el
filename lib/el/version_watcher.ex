defmodule El.VersionWatcher do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_opts) do
    Process.send_after(self(), :check_version, 60_000)
    {:ok, %{}}
  end

  def handle_info(:check_version, state) do
    check_for_update()
    Process.send_after(self(), :check_version, 60_000)
    {:noreply, state}
  end

  def check_for_update do
    current = current_version()
    installed = installed_version()

    if current != installed && installed != :not_found do
      restart()
    end

    :ok
  end

  defp restart do
    Application.get_env(:el, :restart_fn, fn -> :init.restart() end).()
  end

  def current_version do
    Application.spec(:el, :vsn) |> List.to_string()
  end

  def installed_version do
    case System.get_env("RELEASE_ROOT") do
      nil ->
        :not_found

      release_root ->
        path = Path.join([release_root, "releases", "start_erl.data"])

        case File.read(path) do
          {:ok, content} ->
            content
            |> String.trim()
            |> String.split()
            |> Enum.at(1)

          {:error, _} ->
            :not_found
        end
    end
  end
end
