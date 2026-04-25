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
    case {current_version(), installed_version()} do
      {same, same} -> :ok
      {_, :not_found} -> :ok
      _ -> restart()
    end
  end

  defp restart do
    Application.get_env(:el, :restart_fn, fn -> :init.restart() end).()
  end

  def current_version do
    Application.spec(:el, :vsn) |> List.to_string()
  end

  def installed_version do
    System.get_env("RELEASE_ROOT") |> read_installed_version()
  end

  defp read_installed_version(nil), do: :not_found

  defp read_installed_version(release_root) do
    Path.join([release_root, "releases", "start_erl.data"])
    |> File.read()
    |> parse_version()
  end

  defp parse_version({:ok, content}) do
    content |> String.trim() |> String.split() |> Enum.at(1)
  end

  defp parse_version({:error, _}), do: :not_found
end
