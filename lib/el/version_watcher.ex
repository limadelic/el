defmodule El.VersionWatcher do
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
